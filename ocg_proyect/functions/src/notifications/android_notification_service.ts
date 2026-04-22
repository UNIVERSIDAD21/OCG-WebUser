import {logger} from 'firebase-functions';

import type {AndroidNotificationPayload, AndroidDeliveryResult} from './fcm_delivery';
import {sendAndroidFcmNotification} from './fcm_delivery';
import {persistNotificationHistory} from './notification_history';

export interface DeliverAndroidNotificationInput extends AndroidNotificationPayload {
  source: string;
  notificationId?: string;
}

export interface DeliverAndroidNotificationResult {
  notificationId: string;
  delivery: AndroidDeliveryResult;
}

export async function deliverAndroidNotification(
  db: FirebaseFirestore.Firestore,
  input: DeliverAndroidNotificationInput,
): Promise<DeliverAndroidNotificationResult> {
  logger.info('Delivering Android notification', {
    notificationId: input.notificationId ?? null,
    recipientId: input.recipientId,
    recipientRole: input.recipientRole,
    type: input.type,
    source: input.source,
    entityId: input.entityId ?? null,
    entityType: input.entityType ?? null,
  });

  const delivery = await sendAndroidFcmNotification(db, input);
  const notificationId = await persistNotificationHistory(
    db,
    {
      ...input,
      channel: 'app',
      delivery,
    },
    input.notificationId,
  );

  logger.info('Android notification persisted', {
    notificationId,
    recipientId: input.recipientId,
    type: input.type,
    source: input.source,
    deliveryStatus: delivery.status,
    attempted: delivery.attempted,
    successCount: delivery.successCount,
    failureCount: delivery.failureCount,
  });

  return {
    notificationId,
    delivery,
  };
}
