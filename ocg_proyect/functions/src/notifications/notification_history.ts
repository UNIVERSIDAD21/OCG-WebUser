import * as admin from 'firebase-admin';

import type {AndroidDeliveryResult, AndroidNotificationPayload} from './fcm_delivery';

export interface PersistNotificationHistoryInput extends AndroidNotificationPayload {
  source: string;
  channel?: 'app';
  delivery?: AndroidDeliveryResult;
}

function buildDeliverySnapshot(delivery?: AndroidDeliveryResult): Record<string, unknown> {
  if (!delivery) {
    return {
      status: 'failed',
      attempted: 0,
      successCount: 0,
      failureCount: 0,
      invalidDeviceIds: [],
      providerMessageIds: [],
      errors: [],
    };
  }

  return {
    status: delivery.status,
    attempted: delivery.attempted,
    successCount: delivery.successCount,
    failureCount: delivery.failureCount,
    invalidDeviceIds: delivery.invalidDeviceIds,
    providerMessageIds: delivery.providerMessageIds,
    errors: delivery.errors,
  };
}

export async function persistNotificationHistory(
  db: FirebaseFirestore.Firestore,
  input: PersistNotificationHistoryInput,
  docId?: string,
): Promise<string> {
  const ref = docId
    ? db.collection('notifications').doc(docId)
    : db.collection('notifications').doc();

  await ref.set(
    {
      id: ref.id,
      recipientId: input.recipientId,
      recipientRole: input.recipientRole,
      title: input.title,
      body: input.body,
      type: input.type,
      channel: input.channel ?? 'app',
      read: false,
      targetRoute: input.targetRoute ?? null,
      entityId: input.entityId ?? null,
      entityType: input.entityType ?? null,
      appointmentId: input.entityType === 'appointment' ? input.entityId ?? null : null,
      treatmentId: input.entityType === 'treatment' ? input.entityId ?? null : null,
      payload: input.data ?? {},
      source: input.source,
      delivery: buildDeliverySnapshot(input.delivery),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return ref.id;
}
