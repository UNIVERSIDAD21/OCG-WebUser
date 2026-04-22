import {onCall, HttpsError} from 'firebase-functions/v2/https';

import {db} from '../core/firebase';
import {
  type AndroidNotificationPayload,
  sendAndroidFcmNotification,
} from './fcm_delivery';
import {persistNotificationHistory} from './notification_history';

export const sendAndroidNotification = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'User not authenticated');
  }

  const recipientId = String(request.data?.recipientId ?? '').trim();
  const recipientRole = request.data?.recipientRole === 'admin' ? 'admin' : 'patient';
  const title = String(request.data?.title ?? '').trim();
  const body = String(request.data?.body ?? '').trim();
  const type = String(request.data?.type ?? '').trim();

  if (!recipientId || !title || !body || !type) {
    throw new HttpsError('invalid-argument', 'Missing notification fields');
  }

  const payload: AndroidNotificationPayload = {
    recipientId,
    recipientRole,
    title,
    body,
    type,
    targetRoute: String(request.data?.targetRoute ?? '').trim() || undefined,
    entityId: String(request.data?.entityId ?? '').trim() || undefined,
    entityType: String(request.data?.entityType ?? '').trim() || undefined,
    data: typeof request.data?.data === 'object' && request.data?.data !== null
      ? Object.fromEntries(
          Object.entries(request.data.data as Record<string, unknown>).map(([key, value]) => [
            key,
            String(value ?? ''),
          ]),
        )
      : {},
  };

  const delivery = await sendAndroidFcmNotification(db, payload);
  const notificationId = await persistNotificationHistory(db, {
    ...payload,
    source: 'callable:sendAndroidNotification',
    delivery,
  });

  return {
    ok: true,
    notificationId,
    delivery,
  };
});
