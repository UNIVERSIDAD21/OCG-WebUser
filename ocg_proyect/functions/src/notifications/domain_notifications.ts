import * as admin from 'firebase-admin';

import {deliverAndroidNotification} from './android_notification_service';
import {persistNotificationHistory} from './notification_history';

const BOGOTA_TIME_ZONE = 'America/Bogota';

export type AppointmentEventType =
  | 'appointment_created'
  | 'appointment_cancelled'
  | 'appointment_rescheduled'
  | 'appointment_reminder'
  | 'appointment_pending_confirmation';

export type PaymentEventType =
  | 'payment_received'
  | 'payment_due'
  | 'payment_reported'
  | 'payment_pending_validation'
  | 'payment_failed'
  | 'payment_overdue'
  | 'payment_due_soon';
export type TreatmentEventType = 'treatment_stage_updated';

export function asDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

export function formatDateTimeBogota(value: unknown): string {
  const date = asDate(value);
  if (!date) return 'fecha pendiente';
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: BOGOTA_TIME_ZONE,
    dateStyle: 'full',
    timeStyle: 'short',
  }).format(date);
}

export function formatDateBogota(value: unknown): string {
  const date = asDate(value);
  if (!date) return 'fecha pendiente';
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: BOGOTA_TIME_ZONE,
    dateStyle: 'full',
  }).format(date);
}

export function formatCop(value: unknown): string {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    maximumFractionDigits: 0,
  }).format(Number.isFinite(amount) ? amount : 0);
}

async function resolveAdminIds(db: FirebaseFirestore.Firestore): Promise<string[]> {
  const snapshot = await db.collection('admins').get();
  return snapshot.docs.map((doc) => doc.id).filter((id) => id.trim().length > 0);
}

async function deliverAdminNotification(
  db: FirebaseFirestore.Firestore,
  input: {
    baseNotificationId: string;
    type: string;
    title: string;
    body: string;
    targetRoute: string;
    entityId?: string;
    entityType?: string;
    payload?: Record<string, string>;
    sourceRole: 'patient' | 'admin' | 'system';
    sourceUserId?: string;
    sendPush: boolean;
  },
): Promise<void> {
  const adminIds = await resolveAdminIds(db);
  if (adminIds.length == 0) return;

  await Promise.all(
    adminIds.map(async (adminId) => {
      const notificationId = `${input.baseNotificationId}_${adminId}`;
      const data = {
        ...(input.payload ?? {}),
        sourceRole: input.sourceRole,
        sourceUserId: input.sourceUserId ?? '',
      };

      if (input.sendPush) {
        await deliverAndroidNotification(db, {
          notificationId,
          recipientId: adminId,
          recipientRole: 'admin',
          title: input.title,
          body: input.body,
          type: input.type,
          targetRoute: input.targetRoute,
          entityId: input.entityId,
          entityType: input.entityType,
          data,
          source: `trigger:${input.type}`,
        });
        return;
      }

      await persistNotificationHistory(
        db,
        {
          recipientId: adminId,
          recipientRole: 'admin',
          title: input.title,
          body: input.body,
          type: input.type,
          targetRoute: input.targetRoute,
          entityId: input.entityId,
          entityType: input.entityType,
          data,
          source: `trigger:${input.type}`,
        },
        notificationId,
      );
    }),
  );
}

export async function notifyPatientAppointmentEvent(
  db: FirebaseFirestore.Firestore,
  input: {
    notificationId: string;
    patientId: string;
    appointmentId: string;
    treatmentId?: string | null;
    type: AppointmentEventType;
    title: string;
    body: string;
    appointmentAt?: unknown;
    previousAppointmentAt?: unknown;
  },
): Promise<void> {
  await deliverAndroidNotification(db, {
    notificationId: input.notificationId,
    recipientId: input.patientId,
    recipientRole: 'patient',
    title: input.title,
    body: input.body,
    type: input.type,
    targetRoute: '/patient/appointments',
    entityId: input.appointmentId,
    entityType: 'appointment',
    data: {
      appointmentId: input.appointmentId,
      treatmentId: (input.treatmentId ?? '').toString(),
      appointmentAt: asDate(input.appointmentAt)?.toISOString() ?? '',
      previousAppointmentAt: asDate(input.previousAppointmentAt)?.toISOString() ?? '',
    },
    source: `trigger:${input.type}`,
  });
}

export async function notifyAdminAppointmentEvent(
  db: FirebaseFirestore.Firestore,
  input: {
    notificationId: string;
    patientId: string;
    patientName: string;
    appointmentId: string;
    treatmentId?: string | null;
    type:
      | 'appointment_created'
      | 'appointment_cancelled'
      | 'appointment_rescheduled'
      | 'appointment_pending_confirmation';
    title: string;
    body: string;
    appointmentAt?: unknown;
    previousAppointmentAt?: unknown;
    sourceRole: 'patient' | 'admin' | 'system';
    sourceUserId?: string;
    sendPush?: boolean;
  },
): Promise<void> {
  const route = `/admin/patients/${input.patientId}?section=citas`;
  await deliverAdminNotification(db, {
    baseNotificationId: input.notificationId,
    type: input.type,
    title: input.title,
    body: input.body,
    targetRoute: route,
    entityId: input.appointmentId,
    entityType: 'appointment',
    sourceRole: input.sourceRole,
    sourceUserId: input.sourceUserId,
    sendPush: input.sendPush ?? true,
    payload: {
      patientId: input.patientId,
      patientName: input.patientName,
      appointmentId: input.appointmentId,
      treatmentId: (input.treatmentId ?? '').toString(),
      appointmentAt: asDate(input.appointmentAt)?.toISOString() ?? '',
      previousAppointmentAt: asDate(input.previousAppointmentAt)?.toISOString() ?? '',
    },
  });
}

export async function notifyPatientPaymentEvent(
  db: FirebaseFirestore.Firestore,
  input: {
    notificationId: string;
    patientId: string;
    paymentId: string;
    treatmentId?: string | null;
    type: PaymentEventType;
    title: string;
    body: string;
    amount?: unknown;
    dueDate?: unknown;
    reference?: string | null;
  },
): Promise<void> {
  await deliverAndroidNotification(db, {
    notificationId: input.notificationId,
    recipientId: input.patientId,
    recipientRole: 'patient',
    title: input.title,
    body: input.body,
    type: input.type,
    targetRoute: '/patient/payments',
    entityId: input.paymentId,
    entityType: 'payment',
    data: {
      paymentId: input.paymentId,
      treatmentId: (input.treatmentId ?? '').toString(),
      amount: Number.isFinite(Number(input.amount ?? NaN)) ? String(input.amount) : '',
      dueDate: asDate(input.dueDate)?.toISOString() ?? '',
      reference: (input.reference ?? '').toString(),
    },
    source: `trigger:${input.type}`,
  });
}

export async function notifyAdminPaymentEvent(
  db: FirebaseFirestore.Firestore,
  input: {
    notificationId: string;
    patientId: string;
    patientName: string;
    paymentId: string;
    treatmentId?: string | null;
    transactionId?: string | null;
    type:
      | 'payment_reported'
      | 'payment_pending_validation'
      | 'payment_failed'
      | 'payment_overdue'
      | 'payment_due_soon';
    title: string;
    body: string;
    amount?: unknown;
    dueDate?: unknown;
    reference?: string | null;
    sourceRole: 'patient' | 'admin' | 'system';
    sourceUserId?: string;
    sendPush?: boolean;
  },
): Promise<void> {
  const route = `/admin/patients/${input.patientId}?section=pagos`;
  await deliverAdminNotification(db, {
    baseNotificationId: input.notificationId,
    type: input.type,
    title: input.title,
    body: input.body,
    targetRoute: route,
    entityId: input.paymentId,
    entityType: 'payment',
    sourceRole: input.sourceRole,
    sourceUserId: input.sourceUserId,
    sendPush: input.sendPush ?? true,
    payload: {
      patientId: input.patientId,
      patientName: input.patientName,
      paymentId: input.paymentId,
      treatmentId: (input.treatmentId ?? '').toString(),
      transactionId: (input.transactionId ?? '').toString(),
      amount: Number.isFinite(Number(input.amount ?? NaN)) ? String(input.amount) : '',
      dueDate: asDate(input.dueDate)?.toISOString() ?? '',
      reference: (input.reference ?? '').toString(),
    },
  });
}

export async function notifyPatientTreatmentStageEvent(
  db: FirebaseFirestore.Firestore,
  input: {
    notificationId: string;
    patientId: string;
    treatmentId?: string | null;
    stageHistoryId: string;
    previousStage?: string | null;
    newStage: string;
    title: string;
    body: string;
  },
): Promise<void> {
  await deliverAndroidNotification(db, {
    notificationId: input.notificationId,
    recipientId: input.patientId,
    recipientRole: 'patient',
    title: input.title,
    body: input.body,
    type: 'treatment_stage_updated',
    targetRoute: '/patient',
    entityId: input.treatmentId ?? input.patientId,
    entityType: 'treatment',
    data: {
      patientId: input.patientId,
      treatmentId: (input.treatmentId ?? '').toString(),
      stageHistoryId: input.stageHistoryId,
      previousStage: (input.previousStage ?? '').toString(),
      newStage: input.newStage,
    },
    source: 'trigger:treatment_stage_updated',
  });
}
