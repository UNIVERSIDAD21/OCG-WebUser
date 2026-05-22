import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';

type ReconcileNoShowData = {
  appointmentIds?: string[];
};

type AppointmentLike = {
  id?: string;
  patientId?: string;
  estado?: string;
  fechaHora?: admin.firestore.Timestamp | Date | null;
  duracionMinutos?: number;
};

type ReconcileResult = {
  ok: true;
  updated: number;
  skipped: number;
  checked: number;
  cutoffIso: string;
};

const BOGOTA_TIME_ZONE = 'America/Bogota';
const OPEN_STATUSES = new Set(['programada', 'confirmada']);
const ADMIN_COMPLETION_WINDOW_MS = 24 * 60 * 60 * 1000;
const DEFAULT_BATCH_LIMIT = 200;
const SYSTEM_ACTOR = 'system:auto_no_show';

function db(): FirebaseFirestore.Firestore {
  return admin.firestore();
}

function asDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function completionDeadlineFor(appointment: AppointmentLike): Date | null {
  const appointmentAt = asDate(appointment.fechaHora);
  if (!appointmentAt) return null;

  const parsedDuration = Number(appointment.duracionMinutos ?? 30);
  const durationMinutes =
    Number.isFinite(parsedDuration) && parsedDuration >= 0
      ? parsedDuration
      : 30;
  return new Date(
    appointmentAt.getTime() +
      durationMinutes * 60 * 1000 +
      ADMIN_COMPLETION_WINDOW_MS,
  );
}

export function shouldAutoMarkNoShow(
  appointment: AppointmentLike,
  now = new Date(),
): boolean {
  const status = String(appointment.estado ?? '').trim();
  if (!OPEN_STATUSES.has(status)) return false;

  const deadline = completionDeadlineFor(appointment);
  return !!deadline && deadline.getTime() <= now.getTime();
}

async function assertAdmin(request: CallableRequest<ReconcileNoShowData>): Promise<void> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Autenticacion requerida.');
  }

  const token = (request.auth?.token ?? {}) as Record<string, unknown>;
  if (token.role === 'admin' || token.admin === true) return;

  const adminDoc = await db().collection('admins').doc(uid).get();
  if (adminDoc.exists && adminDoc.data()?.role === 'admin') return;

  throw new HttpsError(
    'permission-denied',
    'Solo un administrador puede ejecutar la conciliacion de citas.',
  );
}

async function updatePatientNextAppointment(
  firestore: FirebaseFirestore.Firestore,
  patientId: string,
  now: Date,
): Promise<void> {
  const cleanPatientId = patientId.trim();
  if (!cleanPatientId) return;

  const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
  const upcoming = await firestore
    .collection('appointments')
    .where('patientId', '==', cleanPatientId)
    .where('fechaHora', '>=', nowTimestamp)
    .orderBy('fechaHora', 'asc')
    .limit(50)
    .get();

  let nextDate: Date | null = null;
  for (const doc of upcoming.docs) {
    const item = doc.data() as AppointmentLike;
    if (!OPEN_STATUSES.has(String(item.estado ?? '').trim())) continue;

    nextDate = asDate(item.fechaHora);
    if (nextDate) break;
  }

  await firestore.collection('patients').doc(cleanPatientId).set(
    {
      proximaCita: nextDate ? admin.firestore.Timestamp.fromDate(nextDate) : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function markAppointmentIfDue(
  firestore: FirebaseFirestore.Firestore,
  appointmentId: string,
  now: Date,
): Promise<{updated: boolean; skipped: boolean; patientId: string | null}> {
  const ref = firestore.collection('appointments').doc(appointmentId);

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      return {updated: false, skipped: true, patientId: null};
    }

    const appointment = snapshot.data() as AppointmentLike;
    if (!shouldAutoMarkNoShow(appointment, now)) {
      return {
        updated: false,
        skipped: true,
        patientId: String(appointment.patientId ?? '').trim() || null,
      };
    }

    const deadline = completionDeadlineFor(appointment);
    transaction.update(ref, {
      estado: 'noAsistio',
      autoNoShow: true,
      noShowReason: 'auto_24h_without_admin_completion',
      noShowAutoMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminCompletionDeadlineAt: deadline
        ? admin.firestore.Timestamp.fromDate(deadline)
        : null,
      lastActionByRole: 'system',
      lastActionBy: SYSTEM_ACTOR,
      updatedByRole: 'system',
      updatedBy: SYSTEM_ACTOR,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      updated: true,
      skipped: false,
      patientId: String(appointment.patientId ?? '').trim() || null,
    };
  });
}

async function reconcileAppointmentIds(
  firestore: FirebaseFirestore.Firestore,
  appointmentIds: string[],
  now: Date,
): Promise<ReconcileResult> {
  let updated = 0;
  let skipped = 0;
  const patientIds = new Set<string>();

  for (const appointmentId of appointmentIds) {
    const result = await markAppointmentIfDue(firestore, appointmentId, now);
    if (result.updated) updated += 1;
    if (result.skipped) skipped += 1;
    if (result.updated && result.patientId) patientIds.add(result.patientId);
  }

  for (const patientId of patientIds) {
    await updatePatientNextAppointment(firestore, patientId, now);
  }

  return {
    ok: true,
    updated,
    skipped,
    checked: appointmentIds.length,
    cutoffIso: new Date(now.getTime() - ADMIN_COMPLETION_WINDOW_MS).toISOString(),
  };
}

export async function reconcileDueNoShowAppointments(
  firestore: FirebaseFirestore.Firestore,
  now = new Date(),
  limit = DEFAULT_BATCH_LIMIT,
): Promise<ReconcileResult> {
  const queryCutoff = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - ADMIN_COMPLETION_WINDOW_MS),
  );
  const appointmentIds = new Set<string>();
  const perStatusLimit = Math.max(1, Math.ceil(limit / OPEN_STATUSES.size));

  for (const status of OPEN_STATUSES) {
    const snapshot = await firestore
      .collection('appointments')
      .where('estado', '==', status)
      .where('fechaHora', '<=', queryCutoff)
      .orderBy('fechaHora', 'asc')
      .limit(perStatusLimit)
      .get();

    for (const doc of snapshot.docs) {
      appointmentIds.add(doc.id);
    }
  }

  return reconcileAppointmentIds(firestore, [...appointmentIds], now);
}

export const reconcileNoShowAppointments = onCall<ReconcileNoShowData>(
  async (request: CallableRequest<ReconcileNoShowData>) => {
    await assertAdmin(request);

    const ids = (request.data?.appointmentIds ?? [])
      .map((id) => id.toString().trim())
      .filter((id) => id.length > 0)
      .slice(0, DEFAULT_BATCH_LIMIT);
    const now = new Date();

    if (ids.length > 0) {
      return reconcileAppointmentIds(db(), ids, now);
    }

    return reconcileDueNoShowAppointments(db(), now);
  },
);

export const processNoShowAppointments = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: BOGOTA_TIME_ZONE,
    region: 'us-central1',
    retryCount: 0,
    memory: '256MiB',
  },
  async () => {
    const result = await reconcileDueNoShowAppointments(db());
    logger.info('Automatic no-show reconciliation completed', result);
  },
);
