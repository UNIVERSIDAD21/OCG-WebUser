import {logger} from 'firebase-functions';

import type {AndroidNotificationPayload, AndroidDeliveryResult} from './fcm_delivery';
import {deliverNotification} from './notification_delivery_service';

export interface DeliverAndroidNotificationInput extends AndroidNotificationPayload {
  source: string;
  notificationId?: string;
}

export interface DeliverAndroidNotificationResult {
  notificationId: string;
  delivery: AndroidDeliveryResult;
}

export async function deliverFcmNotification(
  db: FirebaseFirestore.Firestore,
  input: DeliverAndroidNotificationInput,
): Promise<DeliverAndroidNotificationResult> {
  logger.info('Delivering FCM notification', {
    notificationId: input.notificationId ?? null,
    recipientId: input.recipientId,
    recipientRole: input.recipientRole,
    type: input.type,
    source: input.source,
    entityId: input.entityId ?? null,
    entityType: input.entityType ?? null,
  });

  const result = await deliverNotification(db, {
    ...input,
    channels: {
      app: true,
      email: false,
    },
  });
  const delivery = result.delivery;

  if (!delivery) {
    throw new Error('FCM delivery result missing after FCM-only notification delivery.');
  }

  logger.info('FCM notification persisted', {
    notificationId: result.notificationId,
    recipientId: input.recipientId,
    type: input.type,
    source: input.source,
    deliveryStatus: delivery.status,
    attempted: delivery.attempted,
    successCount: delivery.successCount,
    failureCount: delivery.failureCount,
  });

  return {notificationId: result.notificationId, delivery};
}

export async function deliverAndroidNotification(
  db: FirebaseFirestore.Firestore,
  input: DeliverAndroidNotificationInput,
): Promise<DeliverAndroidNotificationResult> {
  const result = await deliverFcmNotification(db, input);
  return {
    notificationId: result.notificationId,
    delivery: result.delivery,
  };
}
