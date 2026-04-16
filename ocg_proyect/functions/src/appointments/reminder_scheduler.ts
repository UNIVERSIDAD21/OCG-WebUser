import * as admin from 'firebase-admin';
import {onSchedule} from 'firebase-functions/v2/scheduler';

const db = admin.firestore();

const VALID_APPOINTMENT_STATUSES = new Set(['programada', 'confirmada']);
const BLOCKING_APPOINTMENT_STATUSES = new Set([
  'cancelada',
  'noAsistio',
  'reprogramada',
  'completada',
]);

const BOGOTA_TIME_ZONE = 'America/Bogota';
const WHATSAPP_PROVIDER_READY = false;

type ReminderChannel = 'app' | 'whatsapp';
type ReminderKind = 'day_before' | 'hour_before';
type ReminderStatus =
  | 'pending'
  | 'sent'
  | 'cancelled'
  | 'obsolete'
  | 'failed'
  | 'skipped'
  | 'pending_provider';

type AppointmentLike = {
  id: string;
  patientId: string;
  patientName?: string;
  patientPhone?: string;
  fechaHora?: admin.firestore.Timestamp | Date | null;
  estado?: string;
  treatmentId?: string | null;
};

type PatientLike = {
  nombre?: string;
  telefono?: string;
  fcmToken?: string;
};

type ScheduledReminderDraft = {
  id: string;
  appointmentId: string;
  patientId: string;
  treatmentId: string | null;
  channel: ReminderChannel;
  kind: ReminderKind;
  scheduledFor: Date;
  status: ReminderStatus;
  payloadSnapshot: Record<string, unknown>;
  idempotencyKey: string;
  appointmentVersion: number;
};

function asDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function normalizePhone(input?: string | null): string | null {
  const digits = (input ?? '').replace(/\D/g, '');
  if (!digits) return null;
  if (digits.startsWith('57') && digits.length >= 12) return digits;
  if (digits.length === 10) return `57${digits}`;
  return digits.length >= 10 ? digits : null;
}

function buildReminderMessage(
  patientName: string,
  appointmentAt: Date,
  kind: ReminderKind,
): string {
  const when = new Intl.DateTimeFormat('es-CO', {
    timeZone: BOGOTA_TIME_ZONE,
    dateStyle: 'full',
    timeStyle: 'short',
  }).format(appointmentAt);

  if (kind === 'day_before') {
    return `Hola ${patientName}, te recordamos tu cita de ortodoncia para mañana, ${when}.`;
  }
  return `Hola ${patientName}, tu cita de ortodoncia es en aproximadamente 1 hora, ${when}.`;
}

function buildReminderDrafts(
  appointment: AppointmentLike,
  patient: PatientLike,
): ScheduledReminderDraft[] {
  const appointmentAt = asDate(appointment.fechaHora);
  if (!appointmentAt) return [];

  const drafts: ScheduledReminderDraft[] = [];
  const patientName =
    (patient.nombre ?? appointment.patientName ?? '').toString().trim() ||
    'paciente';
  const phone = normalizePhone(
    (patient.telefono ?? appointment.patientPhone ?? '').toString(),
  );
  const fcmToken = (patient.fcmToken ?? '').toString().trim();
  const now = Date.now();
  const appointmentVersion = 1;
  const definitions: Array<{kind: ReminderKind; offsetMs: number}> = [
    {kind: 'day_before', offsetMs: 24 * 60 * 60 * 1000},
    {kind: 'hour_before', offsetMs: 60 * 60 * 1000},
  ];

  for (const def of definitions) {
    const scheduledFor = new Date(appointmentAt.getTime() - def.offsetMs);
    if (scheduledFor.getTime() <= now) continue;

    const payloadBase = {
      patientName,
      appointmentDateIso: appointmentAt.toISOString(),
      appointmentTimeZone: BOGOTA_TIME_ZONE,
      appointmentTimeLabel: new Intl.DateTimeFormat('es-CO', {
        timeZone: BOGOTA_TIME_ZONE,
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(appointmentAt),
    };

    drafts.push({
      id: `${appointment.id}_app_${def.kind}`,
      appointmentId: appointment.id,
      patientId: appointment.patientId,
      treatmentId: appointment.treatmentId ?? null,
      channel: 'app',
      kind: def.kind,
      scheduledFor,
      status: 'pending',
      idempotencyKey: `${appointment.id}_app_${def.kind}_v${appointmentVersion}`,
      appointmentVersion,
      payloadSnapshot: {
        ...payloadBase,
        phone: null,
        hasFcmToken: fcmToken.length > 0,
        message: buildReminderMessage(patientName, appointmentAt, def.kind),
      },
    });

    if (phone) {
      drafts.push({
        id: `${appointment.id}_whatsapp_${def.kind}`,
        appointmentId: appointment.id,
        patientId: appointment.patientId,
        treatmentId: appointment.treatmentId ?? null,
        channel: 'whatsapp',
        kind: def.kind,
        scheduledFor,
        status: WHATSAPP_PROVIDER_READY ? 'pending' : 'pending_provider',
        idempotencyKey: `${appointment.id}_whatsapp_${def.kind}_v${appointmentVersion}`,
        appointmentVersion,
        payloadSnapshot: {
          ...payloadBase,
          phone,
          hasFcmToken: false,
          message: buildReminderMessage(patientName, appointmentAt, def.kind),
        },
      });
    }
  }

  return drafts;
}

async function markExistingReminders(
  appointmentId: string,
  nextStatus: 'cancelled' | 'obsolete' | 'skipped',
): Promise<void> {
  const snapshot = await db
    .collection('scheduledNotifications')
    .where('appointmentId', '==', appointmentId)
    .where('status', 'in', ['pending', 'pending_provider'])
    .get();

  if (snapshot.empty) return;

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      status: nextStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      errorMessage: null,
    });
  }
  await batch.commit();
}

export async function syncAppointmentReminders(
  appointment: AppointmentLike | null,
): Promise<void> {
  if (!appointment?.id) return;

  const estado = (appointment.estado ?? '').toString();
  if (!VALID_APPOINTMENT_STATUSES.has(estado)) {
    const nextStatus: 'cancelled' | 'obsolete' = BLOCKING_APPOINTMENT_STATUSES.has(
      estado,
    )
      ? 'cancelled'
      : 'obsolete';
    await markExistingReminders(appointment.id, nextStatus);
    return;
  }

  const patientSnap = await db.collection('patients').doc(appointment.patientId).get();
  const patient = (patientSnap.data() ?? {}) as PatientLike;
  const drafts = buildReminderDrafts(appointment, patient);
  const desiredIds = new Set(drafts.map((item) => item.id));

  const existing = await db
    .collection('scheduledNotifications')
    .where('appointmentId', '==', appointment.id)
    .get();

  const batch = db.batch();

  for (const doc of existing.docs) {
    if (!desiredIds.has(doc.id)) {
      const currentStatus = (doc.data().status ?? '').toString();
      if (currentStatus === 'sent' || currentStatus === 'cancelled') continue;
      batch.update(doc.ref, {
        status: 'obsolete',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  for (const draft of drafts) {
    const ref = db.collection('scheduledNotifications').doc(draft.id);
    batch.set(
      ref,
      {
        id: draft.id,
        appointmentId: draft.appointmentId,
        patientId: draft.patientId,
        treatmentId: draft.treatmentId,
        channel: draft.channel,
        kind: draft.kind,
        scheduledFor: admin.firestore.Timestamp.fromDate(draft.scheduledFor),
        status: draft.status,
        payloadSnapshot: draft.payloadSnapshot,
        idempotencyKey: draft.idempotencyKey,
        appointmentVersion: draft.appointmentVersion,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: null,
        failedAt: null,
        errorMessage: null,
      },
      {merge: true},
    );
  }

  await batch.commit();
}

async function sendPushIfPossible(
  patientId: string,
  title: string,
  body: string,
): Promise<boolean> {
  const patientSnap = await db.collection('patients').doc(patientId).get();
  const token = (patientSnap.data()?.fcmToken ?? '').toString().trim();
  if (!token) return false;

  try {
    await admin.messaging().send({
      token,
      notification: {title, body},
      data: {
        kind: 'appointment_reminder',
      },
    });
    return true;
  } catch {
    return false;
  }
}

export const processScheduledNotifications = onSchedule(
  {
    schedule: 'every 10 minutes',
    timeZone: BOGOTA_TIME_ZONE,
    retryCount: 0,
    memory: '256MiB',
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection('scheduledNotifications')
      .where('status', '==', 'pending')
      .where('scheduledFor', '<=', now)
      .limit(50)
      .get();

    for (const doc of snapshot.docs) {
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists) return;

        const reminder = fresh.data() as Record<string, unknown>;
        if (reminder.status !== 'pending') return;

        const appointmentRef = db
          .collection('appointments')
          .doc((reminder.appointmentId ?? '').toString());
        const appointmentSnap = await tx.get(appointmentRef);
        const appointment = appointmentSnap.data() as AppointmentLike | undefined;
        if (
          !appointmentSnap.exists ||
          !appointment ||
          !VALID_APPOINTMENT_STATUSES.has((appointment.estado ?? '').toString())
        ) {
          tx.update(doc.ref, {
            status: 'skipped',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            errorMessage: 'La cita ya no está en estado válido para recordatorio.',
          });
          return;
        }

        const notificationRef = db.collection('notifications').doc(doc.id);
        const title =
          reminder.kind === 'day_before'
            ? 'Recordatorio de cita mañana'
            : 'Recordatorio de cita en 1 hora';
        const body =
          (reminder.payloadSnapshot as Record<string, unknown> | undefined)
            ?.message
            ?.toString() ?? 'Tienes una cita próxima.';

        tx.set(
          notificationRef,
          {
            id: doc.id,
            recipientId: reminder.patientId,
            channel: 'app',
            type: 'appointment_reminder',
            title,
            body,
            appointmentId: reminder.appointmentId,
            treatmentId: reminder.treatmentId ?? null,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        tx.update(doc.ref, {
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          errorMessage: null,
        });
      });

      const data = doc.data() as Record<string, unknown>;
      const title =
        data.kind === 'day_before'
          ? 'Recordatorio de cita mañana'
          : 'Recordatorio de cita en 1 hora';
      const body =
        (data.payloadSnapshot as Record<string, unknown> | undefined)
          ?.message
          ?.toString() ?? 'Tienes una cita próxima.';
      await sendPushIfPossible((data.patientId ?? '').toString(), title, body);
    }
  },
);
