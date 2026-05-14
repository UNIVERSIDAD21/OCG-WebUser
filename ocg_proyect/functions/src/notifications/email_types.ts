import type {NotificationPayload, NotificationRecipientRole} from './fcm_delivery';

export type EmailProvider =
  | 'disabled'
  | 'brevo'
  | 'resend'
  | 'sendgrid'
  | 'mailgun'
  | 'smtp'
  | 'mock'
  | 'unknown';

export type EmailDeliveryStatus =
  | 'sent'
  | 'failed'
  | 'skipped_no_email'
  | 'skipped_disabled'
  | 'skipped_unverified'
  | 'pending';

export interface EmailRecipient {
  recipientId: string;
  recipientRole: NotificationRecipientRole;
  email: string;
  sourceField: string;
  emailVerified?: boolean | null;
}

export interface EmailDeliveryError {
  code: string;
  message: string;
}

export interface EmailDeliveryResult {
  status: EmailDeliveryStatus;
  attempted: number;
  successCount: number;
  failureCount: number;
  to: string | null;
  provider: EmailProvider;
  providerMessageId: string | null;
  error: EmailDeliveryError | null;
}

export interface EmailNotificationPayload extends NotificationPayload {
  notificationId?: string;
  source: string;
}

export type ResolveEmailRecipientResult =
  | {ok: true; recipient: EmailRecipient}
  | {
      ok: false;
      status: Extract<EmailDeliveryStatus, 'skipped_no_email'>;
      reason: string;
      recipientId: string;
      recipientRole: NotificationRecipientRole;
    };
