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

  return {
    notificationId,
    delivery,
  };
}
