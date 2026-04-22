import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';
import {onSchedule} from 'firebase-functions/v2/scheduler';

import {deliverAndroidNotification} from '../notifications/android_notification_service';

function db(): FirebaseFirestore.Firestore {
  return admin.firestore();
}

const VALID_APPOINTMENT_STATUSES = new Set(['programada', 'confirmada']);
const BLOCKING_APPOINTMENT_STATUSES = new Set([
  'cancelada',
  'noAsistio',
  'reprogramada',
  'completada',
]);

const BOGOTA_TIME_ZONE = 'America/Bogota';

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
  remindersEnabled?: boolean;
};

type PatientLike = {
  nombre?: string;
  telefono?: string;
  fcmToken?: string;
  contactPreferences?: {
    allowWhatsappReminders?: boolean;
    allowPushReminders?: boolean;
    preferredReminderPhone?: string;
    guardianPhone?: string | null;
  };
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

type SendResult = {
  ok: boolean;
  providerMessageId?: string | null;
  errorCode?: string | null;
  errorMessage?: string | null;
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
    return `Hola ${patientName}, te recordamos tu cita en OCG Clínica mañana, ${when}. Si necesitas reprogramar, contáctanos a tiempo.`;
  }
  return `Hola ${patientName}, tu cita en OCG Clínica es en aproximadamente 1 hora, ${when}. Te esperamos.`;
}

function whatsappProviderConfig(): {
  configured: boolean;
  provider: string;
  accessToken?: string;
  phoneNumberId?: string;
} {
  const provider = (process.env.WHATSAPP_PROVIDER ?? '').trim().toLowerCase();
  if (provider !== 'meta') {
    return {configured: false, provider};
  }

  const accessToken = (process.env.WHATSAPP_ACCESS_TOKEN ?? '').trim();
  const phoneNumberId = (process.env.WHATSAPP_PHONE_NUMBER_ID ?? '').trim();

  return {
    configured: accessToken.length > 0 && phoneNumberId.length > 0,
    provider,
    accessToken,
    phoneNumberId,
  };
}

function resolveReminderPhone(
  patient: PatientLike,
  appointment: AppointmentLike,
): string | null {
  const preferred = patient.contactPreferences?.preferredReminderPhone ?? 'patient';
  const patientPhone = normalizePhone(
    (patient.telefono ?? appointment.patientPhone ?? '').toString(),
  );
  const guardianPhone = normalizePhone(
    patient.contactPreferences?.guardianPhone?.toString(),
  );

  if (preferred === 'guardian' && guardianPhone) return guardianPhone;
  if (preferred === 'both') return guardianPhone ?? patientPhone;
  return patientPhone ?? guardianPhone;
}

function buildReminderDrafts(
  appointment: AppointmentLike,
  patient: PatientLike,
): ScheduledReminderDraft[] {
  const appointmentAt = asDate(appointment.fechaHora);
  if (!appointmentAt) return [];
  if (appointment.remindersEnabled == false) return [];

  const drafts: ScheduledReminderDraft[] = [];
  const patientName =
    (patient.nombre ?? appointment.patientName ?? '').toString().trim() ||
    'paciente';
  const phone = resolveReminderPhone(patient, appointment);
  const fcmToken = (patient.fcmToken ?? '').toString().trim();
  const allowWhatsapp = patient.contactPreferences?.allowWhatsappReminders ?? true;
  const allowPush = patient.contactPreferences?.allowPushReminders ?? true;
  const now = Date.now();
  const appointmentVersion = 1;
  const whatsappConfig = whatsappProviderConfig();
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
      message: buildReminderMessage(patientName, appointmentAt, def.kind),
    };

    if (allowPush) {
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
          hasFcmToken: fcmToken.length > 0,
          phone: null,
        },
      });
    }

    if (allowWhatsapp && phone) {
      drafts.push({
        id: `${appointment.id}_whatsapp_${def.kind}`,
        appointmentId: appointment.id,
        patientId: appointment.patientId,
        treatmentId: appointment.treatmentId ?? null,
        channel: 'whatsapp',
        kind: def.kind,
        scheduledFor,
        status: whatsappConfig.configured ? 'pending' : 'pending_provider',
        idempotencyKey: `${appointment.id}_whatsapp_${def.kind}_v${appointmentVersion}`,
        appointmentVersion,
        payloadSnapshot: {
          ...payloadBase,
          phone,
          provider: whatsappConfig.provider,
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
  const snapshot = await db()
    .collection('scheduledNotifications')
    .where('appointmentId', '==', appointmentId)
    .where('status', 'in', ['pending', 'pending_provider'])
    .get();

  if (snapshot.empty) return;

  const batch = db().batch();
  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      status: nextStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      errorCode: null,
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

  const patientSnap = await db().collection('patients').doc(appointment.patientId).get();
  const patient = (patientSnap.data() ?? {}) as PatientLike;
  const drafts = buildReminderDrafts(appointment, patient);
  const desiredIds = new Set(drafts.map((item) => item.id));

  const existing = await db()
    .collection('scheduledNotifications')
    .where('appointmentId', '==', appointment.id)
    .get();

  const batch = db().batch();

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
    const ref = db().collection('scheduledNotifications').doc(draft.id);
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
        attemptCount: 0,
        lastAttemptAt: null,
        providerMessageId: null,
        errorCode: null,
        errorMessage: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: null,
        failedAt: null,
      },
      {merge: true},
    );
  }

  await batch.commit();
}

async function sendAppReminder(
  reminderId: string,
  reminder: Record<string, unknown>,
): Promise<SendResult> {
  const title =
    reminder.kind === 'day_before'
      ? 'Recordatorio de cita mañana'
      : 'Recordatorio de cita en 1 hora';
  const body =
    (reminder.payloadSnapshot as Record<string, unknown> | undefined)?.message?.toString() ??
    'Tienes una cita próxima.';

  const patientId = (reminder.patientId ?? '').toString().trim();
  const appointmentId = (reminder.appointmentId ?? '').toString().trim();
  const treatmentId = (reminder.treatmentId ?? '').toString().trim();
  const kind = (reminder.kind ?? '').toString().trim();

  const {delivery} = await deliverAndroidNotification(db(), {
    notificationId: reminderId,
    recipientId: patientId,
    recipientRole: 'patient',
    title,
    body,
    type: 'appointment_reminder',
    targetRoute: '/patient/appointments',
    entityId: appointmentId || undefined,
    entityType: 'appointment',
    data: {
      kind,
      appointmentId,
      treatmentId,
      reminderId,
    },
    source: 'scheduler:appointment_reminder',
  });

  const ok = delivery.status === 'sent' || delivery.status === 'partial';
  const errorCode = delivery.status === 'skipped_no_active_tokens'
    ? 'SKIPPED_NO_ACTIVE_TOKENS'
    : (delivery.errors[0]?.code ?? null);
  const errorMessage = delivery.status === 'skipped_no_active_tokens'
    ? 'No hay tokens activos para entrega push real.'
    : (delivery.errors[0]?.message ?? null);

  logger.info('Appointment reminder app delivery evaluated', {
    reminderId,
    patientId,
    appointmentId,
    treatmentId,
    kind,
    deliveryStatus: delivery.status,
    attempted: delivery.attempted,
    successCount: delivery.successCount,
    failureCount: delivery.failureCount,
    ok,
    errorCode,
    errorMessage,
  });

  return {
    ok,
    providerMessageId: delivery.providerMessageIds[0] ?? null,
    errorCode,
    errorMessage,
  };
}

async function sendWhatsappReminder(
  reminder: Record<string, unknown>,
): Promise<SendResult> {
  const config = whatsappProviderConfig();
  if (!config.configured || config.provider !== 'meta') {
    return {
      ok: false,
      errorCode: 'WHATSAPP_PROVIDER_NOT_CONFIGURED',
      errorMessage: 'Proveedor WhatsApp no configurado.',
    };
  }

  const payload = (reminder.payloadSnapshot as Record<string, unknown> | undefined) ?? {};
  const phone = (payload['phone'] ?? '').toString().trim();
  const message = (payload['message'] ?? '').toString().trim();
  if (!phone || !message) {
    return {
      ok: false,
      errorCode: 'WHATSAPP_INVALID_PAYLOAD',
      errorMessage: 'Payload de WhatsApp incompleto.',
    };
  }

  try {
    const response = await fetch(
      `https://graph.facebook.com/v23.0/${config.phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: phone,
          type: 'text',
          text: {body: message},
        }),
      },
    );

    const json = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      const error = (json['error'] as Record<string, unknown> | undefined) ?? {};
      return {
        ok: false,
        errorCode: (error['code'] ?? 'WHATSAPP_HTTP_ERROR').toString(),
        errorMessage: (error['message'] ?? 'No se pudo enviar WhatsApp.').toString(),
      };
    }

    const messages = (json['messages'] as Array<Record<string, unknown>> | undefined) ?? [];
    return {
      ok: true,
      providerMessageId: messages.length > 0 ? (messages[0]['id'] ?? '').toString() : null,
    };
  } catch (error) {
    return {
      ok: false,
      errorCode: 'WHATSAPP_REQUEST_FAILED',
      errorMessage: error instanceof Error ? error.message : 'No se pudo ejecutar la petición WhatsApp.',
    };
  }
}

async function processReminderDoc(doc: admin.firestore.QueryDocumentSnapshot): Promise<void> {
  const reminder = doc.data() as Record<string, unknown>;
  const appointmentRef = db().collection('appointments').doc((reminder.appointmentId ?? '').toString());
  const appointmentSnap = await appointmentRef.get();
  const appointment = appointmentSnap.data() as AppointmentLike | undefined;

  if (
    !appointmentSnap.exists ||
    !appointment ||
    !VALID_APPOINTMENT_STATUSES.has((appointment.estado ?? '').toString())
  ) {
    await doc.ref.update({
      status: 'skipped',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      attemptCount: admin.firestore.FieldValue.increment(1),
      errorCode: 'APPOINTMENT_INVALID_STATE',
      errorMessage: 'La cita ya no está en estado válido para recordatorio.',
    });
    return;
  }

  let result: SendResult;
  if (reminder.channel === 'whatsapp') {
    result = await sendWhatsappReminder(reminder);
  } else {
    result = await sendAppReminder(doc.id, reminder);
  }

  await doc.ref.update({
    status: result.ok ? 'sent' : 'failed',
    sentAt: result.ok ? admin.firestore.FieldValue.serverTimestamp() : null,
    failedAt: result.ok ? null : admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    attemptCount: admin.firestore.FieldValue.increment(1),
    providerMessageId: result.providerMessageId ?? null,
    errorCode: result.errorCode ?? null,
    errorMessage: result.errorMessage ?? null,
  });

  logger.info('Scheduled reminder processed', {
    reminderId: doc.id,
    appointmentId: reminder.appointmentId ?? null,
    patientId: reminder.patientId ?? null,
    channel: reminder.channel ?? null,
    kind: reminder.kind ?? null,
    finalStatus: result.ok ? 'sent' : 'failed',
    providerMessageId: result.providerMessageId ?? null,
    errorCode: result.errorCode ?? null,
    errorMessage: result.errorMessage ?? null,
  });

  if (result.ok && reminder.channel === 'app') {
    const reminderKind = (reminder.kind ?? '').toString();
    if (reminderKind === 'day_before' || reminderKind === 'hour_before') {
      await appointmentRef.set(
        {
          [reminderKind === 'day_before' ? 'recordatorio24hEnviado' : 'recordatorio2hEnviado']:
            true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }
}

async function dueReminderSnapshots(): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const now = admin.firestore.Timestamp.now();
  const scheduled = db().collection('scheduledNotifications');
  const snapshots = [
    await scheduled.where('status', '==', 'pending').where('scheduledFor', '<=', now).limit(50).get(),
  ];

  if (whatsappProviderConfig().configured) {
    snapshots.push(
      await scheduled
        .where('status', '==', 'pending_provider')
        .where('scheduledFor', '<=', now)
        .limit(50)
        .get(),
    );
  }

  const seen = new Set<string>();
  const docs: admin.firestore.QueryDocumentSnapshot[] = [];
  for (const finalSnap of snapshots) {
    for (const doc of finalSnap.docs) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      docs.push(doc);
    }
  }
  return docs;
}

export const processScheduledNotifications = onSchedule(
  {
    schedule: 'every 10 minutes',
    timeZone: BOGOTA_TIME_ZONE,
    retryCount: 0,
    memory: '256MiB',
  },
  async () => {
    const docs = await dueReminderSnapshots();
    for (const doc of docs) {
      await processReminderDoc(doc);
    }
  },
);
