import type {EmailProvider} from './email_types';

export interface EmailRuntimeConfig {
  enabled: boolean;
  provider: EmailProvider;
  brevoApiKey: string | null;
  from: string | null;
  replyTo: string | null;
  appBaseUrl: string | null;
}

function normalize(value: unknown): string {
  return String(value ?? '').trim();
}

function parseEnabled(value: unknown): boolean {
  const normalized = normalize(value).toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
}

function normalizeProvider(value: unknown): EmailProvider {
  const normalized = normalize(value).toLowerCase();
  if (!normalized) return 'disabled';
  if (
    normalized === 'brevo' ||
    normalized === 'resend' ||
    normalized === 'sendgrid' ||
    normalized === 'mailgun' ||
    normalized === 'smtp' ||
    normalized === 'mock'
  ) {
    return normalized;
  }
  return 'unknown';
}

function normalizeNullable(value: unknown): string | null {
  const normalized = normalize(value);
  return normalized.length > 0 ? normalized : null;
}

export function resolveEmailRuntimeConfig(
  env: NodeJS.ProcessEnv = process.env,
): EmailRuntimeConfig {
  const provider = normalizeProvider(env.EMAIL_PROVIDER);
  return {
    enabled: parseEnabled(env.EMAIL_ENABLED),
    provider,
    brevoApiKey: normalizeNullable(env.BREVO_API_KEY),
    from: normalizeNullable(env.EMAIL_FROM),
    replyTo: normalizeNullable(env.EMAIL_REPLY_TO),
    appBaseUrl: normalizeNullable(env.EMAIL_APP_BASE_URL),
  };
}

export function isEmailRuntimeReady(config: EmailRuntimeConfig): boolean {
  if (!config.enabled || !config.from) return false;
  if (config.provider === 'mock') return true;
  if (config.provider === 'brevo') return Boolean(config.brevoApiKey);
  return false;
}

export function buildEmailAppLink(
  config: Pick<EmailRuntimeConfig, 'appBaseUrl'>,
  targetRoute?: string,
): string | null {
  const baseUrl = normalizeNullable(config.appBaseUrl);
  if (!baseUrl) return null;

  const route = normalize(targetRoute);
  if (!route || !route.startsWith('/') || route.startsWith('//') || route.includes('://')) {
    return baseUrl.replace(/\/+$/, '');
  }

  return `${baseUrl.replace(/\/+$/, '')}${route}`;
}
