import * as admin from 'firebase-admin';

import type {AndroidDeliveryResult, AndroidNotificationPayload} from './fcm_delivery';
import type {EmailDeliveryResult} from './email_types';

export interface PersistNotificationHistoryInput extends AndroidNotificationPayload {
  source: string;
  channel?: 'app' | 'email';
  delivery?: AndroidDeliveryResult;
  emailDelivery?: EmailDeliveryResult;
}

function buildDeliverySnapshot(delivery?: AndroidDeliveryResult): Record<string, unknown> {
  if (!delivery) {
    return {
      status: 'internal_only',
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

function buildChannels(input: PersistNotificationHistoryInput): string[] {
  const channels = new Set<string>();
  channels.add(input.channel ?? 'app');
  if (input.emailDelivery) channels.add('email');
  return [...channels];
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
      channels: buildChannels(input),
      read: false,
      targetRoute: input.targetRoute ?? null,
      entityId: input.entityId ?? null,
      entityType: input.entityType ?? null,
      route: input.targetRoute ?? null,
      appointmentId: input.entityType === 'appointment' ? input.entityId ?? null : null,
      treatmentId: input.entityType === 'treatment' ? input.entityId ?? null : (input.data?.treatmentId ?? null),
      paymentId: input.entityType === 'payment' ? input.entityId ?? null : (input.data?.paymentId ?? null),
      transactionId: input.data?.transactionId ?? null,
      payload: input.data ?? {},
      source: input.source,
      sourceRole: input.data?.sourceRole ?? null,
      sourceUserId: input.data?.sourceUserId ?? null,
      pushSent: (input.delivery?.successCount ?? 0) > 0,
      delivery: buildDeliverySnapshot(input.delivery),
      emailSent: input.emailDelivery?.status === 'sent',
      emailStatus: input.emailDelivery?.status ?? null,
      emailTo: input.emailDelivery?.to ?? null,
      emailProvider: input.emailDelivery?.provider ?? null,
      emailProviderMessageId: input.emailDelivery?.providerMessageId ?? null,
      emailAttemptedAt:
        (input.emailDelivery?.attempted ?? 0) > 0
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
      emailError: input.emailDelivery?.error ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return ref.id;
}
