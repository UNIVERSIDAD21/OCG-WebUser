import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {
  type AndroidNotificationPayload,
  type NotificationRecipientRole,
} from './fcm_delivery';
import {deliverNotification} from './notification_delivery_service';

type SendAndroidNotificationRequest = {
  recipientId?: unknown;
  recipientRole?: unknown;
  title?: unknown;
  body?: unknown;
  type?: unknown;
  targetRoute?: unknown;
  entityId?: unknown;
  entityType?: unknown;
  data?: unknown;
  sendEmail?: unknown;
};

function requireAdmin(request: CallableRequest<SendAndroidNotificationRequest>): void {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  }

  const role = request.auth?.token?.role;
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo admin puede enviar notificaciones.');
  }
}

function normalizeRecipientRole(value: unknown): NotificationRecipientRole {
  return value === 'admin' ? 'admin' : 'patient';
}

function normalizeStringRecord(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, raw]) => [
      key,
      String(raw ?? ''),
    ]),
  );
}

function normalizeBoolean(value: unknown): boolean | null {
  if (typeof value === 'boolean') return value;
  const normalized = String(value ?? '').trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') return true;
  if (normalized === 'false' || normalized === '0' || normalized === 'no') return false;
  return null;
}

function isPaymentNotification(payload: AndroidNotificationPayload): boolean {
  const type = payload.type.toLowerCase();
  const entityType = (payload.entityType ?? '').toLowerCase();
  return (
    type === 'payment' ||
    type.startsWith('payment_') ||
    type.includes('pago') ||
    entityType === 'payment' ||
    entityType === 'pago'
  );
}

function isTreatmentNotification(payload: AndroidNotificationPayload): boolean {
  const type = payload.type.toLowerCase();
  const entityType = (payload.entityType ?? '').toLowerCase();
  return (
    type === 'treatment_stage_updated' ||
    type.startsWith('treatment_') ||
    type.includes('tratamiento') ||
    entityType === 'treatment' ||
    entityType === 'tratamiento'
  );
}

function isAppointmentNotification(payload: AndroidNotificationPayload): boolean {
  const type = payload.type.toLowerCase();
  const entityType = (payload.entityType ?? '').toLowerCase();
  return type.startsWith('appointment_') || entityType === 'appointment' || entityType === 'cita';
}

function defaultTargetRoute(payload: AndroidNotificationPayload): string | undefined {
  if (payload.targetRoute) return payload.targetRoute;
  if (payload.recipientRole !== 'patient') return undefined;
  if (isPaymentNotification(payload)) return '/patient/payments';
  if (isAppointmentNotification(payload)) return '/patient/appointments';
  if (isTreatmentNotification(payload)) return '/patient';
  return undefined;
}

export function shouldSendEmailForCallable(
  payload: AndroidNotificationPayload,
  request: SendAndroidNotificationRequest,
): boolean {
  if (isPaymentNotification(payload)) return false;
  const explicit = normalizeBoolean(request.sendEmail);
  if (explicit !== null) return explicit;
  return isTreatmentNotification(payload);
}

export function buildPayload(data: SendAndroidNotificationRequest): AndroidNotificationPayload {
  const recipientId = String(data.recipientId ?? '').trim();
  const title = String(data.title ?? '').trim();
  const body = String(data.body ?? '').trim();
  const type = String(data.type ?? '').trim();

  if (!recipientId || !title || !body || !type) {
    throw new HttpsError('invalid-argument', 'Faltan campos obligatorios de la notificación.');
  }

  const payload = {
    recipientId,
    recipientRole: normalizeRecipientRole(data.recipientRole),
    title,
    body,
    type,
    targetRoute: String(data.targetRoute ?? '').trim() || undefined,
    entityId: String(data.entityId ?? '').trim() || undefined,
    entityType: String(data.entityType ?? '').trim() || undefined,
    data: normalizeStringRecord(data.data),
  };

  return {
    ...payload,
    targetRoute: defaultTargetRoute(payload),
  };
}

export const sendAndroidNotification = onCall<SendAndroidNotificationRequest>(async (request) => {
  requireAdmin(request);

  const db = admin.firestore();
  const payload = buildPayload(request.data ?? {});
  const sendEmail = shouldSendEmailForCallable(payload, request.data ?? {});
  const {notificationId, delivery, emailDelivery} = await deliverNotification(db, {
    ...payload,
    source: 'callable:sendAndroidNotification',
    channels: {
      app: true,
      email: sendEmail,
    },
  });

  return {
    ok: true,
    notificationId,
    delivery,
    emailDelivery,
  };
});
