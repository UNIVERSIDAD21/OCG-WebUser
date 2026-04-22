import * as admin from 'firebase-admin';

import type {AndroidDeliveryResult, AndroidNotificationPayload} from './fcm_delivery';

export interface PersistNotificationHistoryInput extends AndroidNotificationPayload {
  source: string;
  delivery?: AndroidDeliveryResult;
}

export async function persistNotificationHistory(
  db: FirebaseFirestore.Firestore,
  input: PersistNotificationHistoryInput,
): Promise<string> {
  const doc = await db.collection('notifications').add({
    recipientId: input.recipientId,
    recipientRole: input.recipientRole,
    title: input.title,
    body: input.body,
    type: input.type,
    read: false,
    targetRoute: input.targetRoute ?? null,
    entityId: input.entityId ?? null,
    entityType: input.entityType ?? null,
    payload: input.data ?? {},
    source: input.source,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    delivery: input.delivery
      ? {
          attempted: input.delivery.attempted,
          successCount: input.delivery.successCount,
          failureCount: input.delivery.failureCount,
          invalidDeviceIds: input.delivery.invalidDeviceIds,
          errors: input.delivery.errors,
        }
      : {
          attempted: 0,
          successCount: 0,
          failureCount: 0,
          invalidDeviceIds: [],
          errors: [],
        },
  });

  return doc.id;
}
