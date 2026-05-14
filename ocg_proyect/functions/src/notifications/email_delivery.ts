import {logger} from 'firebase-functions';

import type {
  EmailDeliveryError,
  EmailDeliveryResult,
  EmailDeliveryStatus,
  EmailNotificationPayload,
  EmailProvider,
  ResolveEmailRecipientResult,
} from './email_types';
import type {NotificationRecipientRole} from './fcm_delivery';
import {
  buildEmailAppLink,
  isEmailRuntimeReady,
  resolveEmailRuntimeConfig,
  type EmailRuntimeConfig,
} from './email_config';
import {renderEmailTemplate} from './email_templates';

const PATIENT_EMAIL_FIELDS = ['email', 'correo', 'patientEmail'];
const ADMIN_EMAIL_FIELDS = ['email'];
const BREVO_SEND_EMAIL_URL = 'https://api.brevo.com/v3/smtp/email';

type EmailFetchResponse = {
  ok: boolean;
  status: number;
  json: () => Promise<unknown>;
  text?: () => Promise<string>;
};

export type EmailFetch = (
  url: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body: string;
  },
) => Promise<EmailFetchResponse>;

export interface SendEmailNotificationOptions {
  env?: NodeJS.ProcessEnv;
  fetchImpl?: EmailFetch;
}

function userCollection(role: NotificationRecipientRole): string {
  return role === 'admin' ? 'admins' : 'patients';
}

function candidateFields(role: NotificationRecipientRole): string[] {
  return role === 'admin' ? ADMIN_EMAIL_FIELDS : PATIENT_EMAIL_FIELDS;
}

function normalizeEmail(value: unknown): string {
  return String(value ?? '').trim().toLowerCase();
}

export function isValidEmail(value: unknown): boolean {
  const email = normalizeEmail(value);
  if (!email || email.length > 320 || email.includes('..')) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Enmascara email para logs — no expone el email completo.
 * Ej: "j***@gmail.com" o "jo***@gmail.com"
 */
export function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!local || !domain) return '***';
  const visible = local.length <= 2 ? local[0] : local.substring(0, 2);
  return `${visible}***@${domain}`;
}

export async function resolveEmailRecipient(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
): Promise<ResolveEmailRecipientResult> {
  const recipientId = uid.trim();
  if (!recipientId) {
    return {
      ok: false,
      status: 'skipped_no_email',
      reason: 'recipient_id_empty',
      recipientId,
      recipientRole: role,
    };
  }

  const snapshot = await db.collection(userCollection(role)).doc(recipientId).get();
  const data = snapshot.data() ?? {};

  for (const field of candidateFields(role)) {
    const email = normalizeEmail(data[field]);
    if (!email) continue;
    if (!isValidEmail(email)) continue;

    // ── Bloque 07: verificar preferencias del usuario ────────────────
    const emailEnabled =
      data.emailEnabled === undefined ? true : Boolean(data.emailEnabled);
    if (!emailEnabled) {
      return {
        ok: false,
        status: 'skipped_user_opt_out',
        reason: 'user_disabled_email',
        recipientId,
        recipientRole: role,
      };
    }

    return {
      ok: true,
      recipient: {
        recipientId,
        recipientRole: role,
        email,
        sourceField: field,
        emailVerified:
          typeof data.emailVerified === 'boolean'
            ? data.emailVerified
            : null,
      },
    };
  }

  return {
    ok: false,
    status: 'skipped_no_email',
    reason: snapshot.exists ? 'no_valid_email_field' : 'recipient_not_found',
    recipientId,
    recipientRole: role,
  };
}

export function buildSkippedEmailDeliveryResult(params: {
  status: Extract<EmailDeliveryStatus, 'skipped_disabled' | 'skipped_no_email' | 'skipped_user_opt_out' | 'skipped_unverified'>;
  provider?: EmailProvider;
  to?: string | null;
  code: string;
  message: string;
}): EmailDeliveryResult {
  return {
    status: params.status,
    attempted: 0,
    successCount: 0,
    failureCount: 0,
    to: params.to ?? null,
    provider: params.provider ?? 'disabled',
    providerMessageId: null,
    error: {
      code: params.code,
      message: params.message,
    },
  };
}

export function buildPendingEmailDeliveryResult(params: {
  provider: EmailProvider;
  to: string;
}): EmailDeliveryResult {
  return {
    status: 'pending',
    attempted: 0,
    successCount: 0,
    failureCount: 0,
    to: params.to,
    provider: params.provider,
    providerMessageId: null,
    error: null,
  };
}

function parseEmailAddress(value: string): {email: string; name?: string} | null {
  const normalized = value.trim();
  const bracketMatch = normalized.match(/^(.*?)<([^<>]+)>$/);
  if (bracketMatch) {
    const name = bracketMatch[1].trim().replace(/^"|"$/g, '');
    const email = normalizeEmail(bracketMatch[2]);
    if (!isValidEmail(email)) return null;
    return {
      email,
      name: name.length > 0 ? name : undefined,
    };
  }

  const email = normalizeEmail(normalized);
  if (!isValidEmail(email)) return null;
  return {email};
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

async function readBrevoResponse(response: EmailFetchResponse): Promise<Record<string, unknown>> {
  try {
    return asRecord(await response.json());
  } catch (_) {
    const body = response.text ? await response.text().catch(() => '') : '';
    return body ? {message: body} : {};
  }
}

function failedResult(params: {
  provider: EmailProvider;
  to: string | null;
  code: string;
  message: string;
  attempted?: number;
}): EmailDeliveryResult {
  const attempted = params.attempted ?? 1;
  return {
    status: 'failed',
    attempted,
    successCount: 0,
    failureCount: attempted,
    to: params.to,
    provider: params.provider,
    providerMessageId: null,
    error: {
      code: params.code,
      message: params.message,
    },
  };
}

function sentResult(params: {
  provider: EmailProvider;
  to: string;
  providerMessageId: string | null;
}): EmailDeliveryResult {
  return {
    status: 'sent',
    attempted: 1,
    successCount: 1,
    failureCount: 0,
    to: params.to,
    provider: params.provider,
    providerMessageId: params.providerMessageId,
    error: null,
  };
}

export function configError(config: EmailRuntimeConfig): EmailDeliveryError {
  if (!config.enabled) {
    return {
      code: 'EMAIL_DISABLED',
      message: 'Email delivery is disabled.',
    };
  }
  if (!config.from) {
    return {
      code: 'EMAIL_FROM_MISSING',
      message: 'EMAIL_FROM is required.',
    };
  }
  if (config.provider === 'brevo' && !config.brevoApiKey) {
    return {
      code: 'BREVO_API_KEY_MISSING',
      message: 'BREVO_API_KEY is required for Brevo delivery.',
    };
  }
  return {
    code: 'EMAIL_PROVIDER_UNSUPPORTED',
    message: `Email provider ${config.provider} is not supported by this adapter.`,
  };
}

export async function sendBrevoEmail(params: {
  config: EmailRuntimeConfig;
  payload: EmailNotificationPayload;
  to: string;
  fetchImpl: EmailFetch;
}): Promise<EmailDeliveryResult> {
  const sender = parseEmailAddress(params.config.from ?? '');
  if (!sender) {
    return failedResult({
      provider: 'brevo',
      to: params.to,
      code: 'EMAIL_FROM_INVALID',
      message: 'EMAIL_FROM must be a valid sender email.',
      attempted: 0,
    });
  }

  const replyTo = params.config.replyTo
    ? parseEmailAddress(params.config.replyTo)
    : null;
  const appLink = buildEmailAppLink(params.config, params.payload.targetRoute);
  const template = renderEmailTemplate(params.payload, {appLink});
  const body = {
    sender,
    to: [{email: params.to}],
    ...(replyTo ? {replyTo} : {}),
    subject: template.subject,
    htmlContent: template.html,
    textContent: template.text,
    tags: ['ocg', params.payload.type],
    headers: {
      'X-OCG-Notification-Id': params.payload.notificationId ?? '',
      'X-OCG-Notification-Type': params.payload.type,
    },
  };

  try {
    const response = await params.fetchImpl(BREVO_SEND_EMAIL_URL, {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'api-key': params.config.brevoApiKey ?? '',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const json = await readBrevoResponse(response);
    if (!response.ok) {
      return failedResult({
        provider: 'brevo',
        to: params.to,
        code: String(json.code ?? `BREVO_HTTP_${response.status}`),
        message: String(json.message ?? 'Brevo rejected the email request.'),
      });
    }

    return sentResult({
      provider: 'brevo',
      to: params.to,
      providerMessageId: String(json.messageId ?? json.id ?? '') || null,
    });
  } catch (error) {
    return failedResult({
      provider: 'brevo',
      to: params.to,
      code: 'BREVO_REQUEST_FAILED',
      message: error instanceof Error ? error.message : 'Brevo request failed.',
    });
  }
}

export async function sendEmailNotification(
  db: FirebaseFirestore.Firestore,
  payload: EmailNotificationPayload,
  options: SendEmailNotificationOptions = {},
): Promise<EmailDeliveryResult> {
  // ── Bloque 08: logging estructurado ──────────────────────────────────
  logger.info('EMAIL_DELIVERY_START', {
    notificationId: payload.notificationId ?? null,
    type: payload.type,
    recipientRole: payload.recipientRole,
    recipientId: payload.recipientId,
    source: payload.source,
  });

  const config = resolveEmailRuntimeConfig(options.env);
  if (!isEmailRuntimeReady(config)) {
    const error = configError(config);
    logger.warn('EMAIL_DELIVERY_SKIPPED', {
      notificationId: payload.notificationId ?? null,
      reason: 'runtime_not_ready',
      code: error.code,
      provider: config.provider,
    });
    return buildSkippedEmailDeliveryResult({
      status: 'skipped_disabled',
      provider: config.provider,
      code: error.code,
      message: error.message,
    });
  }

  const recipient = await resolveEmailRecipient(db, payload.recipientRole, payload.recipientId);
  if (!recipient.ok) {
    logger.warn('EMAIL_DELIVERY_SKIPPED', {
      notificationId: payload.notificationId ?? null,
      reason: recipient.reason,
      status: recipient.status,
      recipientId: recipient.recipientId,
    });
    return buildSkippedEmailDeliveryResult({
      status: recipient.status,
      provider: config.provider,
      code: recipient.reason,
      message: 'Recipient has no valid email address.',
    });
  }

  if (config.provider === 'mock') {
    logger.info('EMAIL_DELIVERY_RESULT', {
      notificationId: payload.notificationId ?? null,
      status: 'sent',
      provider: 'mock',
      recipientPreview: maskEmail(recipient.recipient.email),
    });
    return sentResult({
      provider: 'mock',
      to: recipient.recipient.email,
      providerMessageId: `mock_${payload.notificationId ?? payload.type}`,
    });
  }

  // ── Bloque 07: log seguro sin email completo ────────────────────────
  logger.info('Sending email notification', {
    notificationId: payload.notificationId ?? null,
    type: payload.type,
    recipientRole: payload.recipientRole,
    recipientPreview: maskEmail(recipient.recipient.email),
    provider: config.provider,
  });

  if (config.provider === 'brevo') {
    const fetchImpl = options.fetchImpl ?? fetch as EmailFetch;
    const result = await sendBrevoEmail({
      config,
      payload,
      to: recipient.recipient.email,
      fetchImpl,
    });

    // ── Bloque 08: log de resultado ─────────────────────────────────
    const logLevel = (s: 'sent' | 'failed') => s === 'sent' ? 'info' : 'error';
    logger[logLevel(result.status as 'sent' | 'failed')](
      result.status === 'sent' ? 'EMAIL_DELIVERY_RESULT' : 'EMAIL_DELIVERY_FAILED',
      {
        notificationId: payload.notificationId ?? null,
        status: result.status,
        provider: result.provider,
        error: result.error,
        providerMessageId: result.providerMessageId ?? null,
        recipientPreview: maskEmail(recipient.recipient.email),
      },
    );
    return result;
  }

  const unsupportedResult = failedResult({
    provider: config.provider,
    to: recipient.recipient.email,
    code: 'EMAIL_PROVIDER_UNSUPPORTED',
    message: `Email provider ${config.provider} is not implemented.`,
    attempted: 0,
  });

  logger.error('EMAIL_DELIVERY_FAILED', {
    notificationId: payload.notificationId ?? null,
    status: 'failed',
    code: 'EMAIL_PROVIDER_UNSUPPORTED',
    provider: config.provider,
    recipientPreview: maskEmail(recipient.recipient.email),
  });

  return unsupportedResult;
}

