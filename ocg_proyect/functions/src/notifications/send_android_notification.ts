import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {
  type AndroidNotificationPayload,
  type NotificationRecipientRole,
} from './fcm_delivery';
import {deliverAndroidNotification} from './android_notification_service';

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

function buildPayload(data: SendAndroidNotificationRequest): AndroidNotificationPayload {
  const recipientId = String(data.recipientId ?? '').trim();
  const title = String(data.title ?? '').trim();
  const body = String(data.body ?? '').trim();
  const type = String(data.type ?? '').trim();

  if (!recipientId || !title || !body || !type) {
    throw new HttpsError('invalid-argument', 'Faltan campos obligatorios de la notificación.');
  }

  return {
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
}

export const sendAndroidNotification = onCall<SendAndroidNotificationRequest>(async (request) => {
  requireAdmin(request);

  const db = admin.firestore();
  const payload = buildPayload(request.data ?? {});
  const {notificationId, delivery} = await deliverAndroidNotification(db, {
    ...payload,
    source: 'callable:sendAndroidNotification',
  });

  return {
    ok: true,
    notificationId,
    delivery,
  };
});
