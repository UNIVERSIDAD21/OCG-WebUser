import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';

import type {AndroidDeliveryResult, NotificationPayload} from './fcm_delivery';
import {sendFcmNotification} from './fcm_delivery';
import type {EmailDeliveryResult} from './email_types';
import {sendEmailNotification, type SendEmailNotificationOptions} from './email_delivery';
import {persistNotificationHistory} from './notification_history';

export interface DeliverNotificationInput extends NotificationPayload {
  source: string;
  notificationId?: string;
  channels?: {
    app?: boolean;
    email?: boolean;
  };
}

export interface DeliverNotificationOptions {
  messagingOverride?: {send(message: admin.messaging.Message): Promise<string>};
  emailOptions?: SendEmailNotificationOptions;
}

export interface DeliverNotificationResult {
  notificationId: string;
  delivery?: AndroidDeliveryResult;
  emailDelivery?: EmailDeliveryResult;
}

function shouldSendApp(input: DeliverNotificationInput): boolean {
  return input.channels?.app ?? true;
}

function shouldSendEmail(input: DeliverNotificationInput): boolean {
  return input.channels?.email ?? true;
}

export async function deliverNotification(
  db: FirebaseFirestore.Firestore,
  input: DeliverNotificationInput,
  options: DeliverNotificationOptions = {},
): Promise<DeliverNotificationResult> {
  const notificationId = input.notificationId ?? db.collection('notifications').doc().id;
  const sendApp = shouldSendApp(input);
  const sendEmail = shouldSendEmail(input);

  logger.info('Delivering notification', {
    notificationId,
    recipientId: input.recipientId,
    recipientRole: input.recipientRole,
    type: input.type,
    source: input.source,
    entityId: input.entityId ?? null,
    entityType: input.entityType ?? null,
    sendApp,
    sendEmail,
  });

  const [delivery, emailDelivery] = await Promise.all([
    sendApp
      ? sendFcmNotification(db, input, options.messagingOverride)
      : Promise.resolve(undefined),
    sendEmail
      ? sendEmailNotification(
        db,
        {
          ...input,
          notificationId,
        },
        options.emailOptions,
      )
      : Promise.resolve(undefined),
  ]);

  await persistNotificationHistory(
    db,
    {
      ...input,
      channel: sendApp ? 'app' : 'email',
      delivery,
      emailDelivery,
    },
    notificationId,
  );

  logger.info('Notification delivery persisted', {
    notificationId,
    recipientId: input.recipientId,
    recipientRole: input.recipientRole,
    type: input.type,
    source: input.source,
    pushStatus: delivery?.status ?? null,
    pushAttempted: delivery?.attempted ?? 0,
    pushSuccessCount: delivery?.successCount ?? 0,
    emailStatus: emailDelivery?.status ?? null,
    emailProvider: emailDelivery?.provider ?? null,
    emailAttempted: emailDelivery?.attempted ?? 0,
    emailSuccessCount: emailDelivery?.successCount ?? 0,
  });

  return {
    notificationId,
    delivery,
    emailDelivery,
  };
}

