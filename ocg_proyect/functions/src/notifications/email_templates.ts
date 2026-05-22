import type {EmailNotificationPayload} from './email_types';

export interface RenderedEmailTemplate {
  subject: string;
  html: string;
  text: string;
}

export interface RenderEmailTemplateOptions {
  appLink?: string | null;
}

const BRAND_NAME = 'OCG - Oral Care Global';

function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function normalize(value: unknown): string {
  return String(value ?? '').trim();
}

function subjectForType(payload: EmailNotificationPayload): string {
  switch (payload.type) {
    case 'payment':
    case 'payment_received':
      return `${BRAND_NAME} - Pago recibido`;
    case 'payment_due':
      return `${BRAND_NAME} - Pago proximo a vencer`;
    case 'payment_due_soon':
      return `${BRAND_NAME} - Pago proximo a vencer`;
    case 'payment_overdue':
      return `${BRAND_NAME} - Pago vencido`;
    case 'payment_failed':
      return `${BRAND_NAME} - Pago no aprobado`;
    case 'payment_pending_validation':
      return `${BRAND_NAME} - Pago pendiente de validacion`;
    case 'payment_reported':
      return `${BRAND_NAME} - Nuevo pago reportado`;
    case 'treatment_stage_updated':
      return `${BRAND_NAME} - Tu tratamiento avanzo`;
    case 'appointment_created':
      return `${BRAND_NAME} - Nueva cita`;
    case 'appointment_confirmed':
      return `${BRAND_NAME} - Cita confirmada`;
    case 'appointment_cancelled':
      return `${BRAND_NAME} - Cita cancelada`;
    case 'appointment_rescheduled':
      return `${BRAND_NAME} - Cita reprogramada`;
    case 'appointment_reminder':
      return `${BRAND_NAME} - Recordatorio de cita`;
    case 'appointment_pending_confirmation':
      return `${BRAND_NAME} - Cita pendiente de confirmacion`;
    default:
      return normalize(payload.title) || `${BRAND_NAME} - Notificacion`;
  }
}

function preheaderForType(type: string): string {
  if (type === 'payment' || type.startsWith('payment_') || type.includes('pago')) {
    return `Actualizacion importante sobre pagos en ${BRAND_NAME}.`;
  }
  if (type === 'treatment_stage_updated') {
    return 'Actualizacion sobre el avance de tu tratamiento.';
  }
  if (type.startsWith('appointment_')) {
    return 'Actualizacion importante sobre tu cita.';
  }
  return `Tienes una nueva notificacion de ${BRAND_NAME}.`;
}

function actionLabelForType(type: string): string {
  if (type === 'payment' || type.startsWith('payment_') || type.includes('pago')) return 'Ver pagos';
  if (type === 'treatment_stage_updated') return 'Ver tratamiento';
  if (type.startsWith('appointment_')) return 'Ver citas';
  return 'Abrir portal';
}

export function renderEmailTemplate(
  payload: EmailNotificationPayload,
  options: RenderEmailTemplateOptions = {},
): RenderedEmailTemplate {
  const subject = subjectForType(payload);
  const title = normalize(payload.title) || subject;
  const body = normalize(payload.body) || `Tienes una nueva notificacion de ${BRAND_NAME}.`;
  const preheader = preheaderForType(payload.type);
  const appLink = normalize(options.appLink);
  const actionLabel = actionLabelForType(payload.type);
  const escapedLink = escapeHtml(appLink);

  const actionHtml = appLink
    ? `
      <p style="margin:24px 0;">
        <a href="${escapedLink}" style="background:#2C2016;border-radius:6px;color:#ffffff;display:inline-block;font-family:Arial,sans-serif;font-size:14px;font-weight:700;padding:12px 18px;text-decoration:none;">
          ${escapeHtml(actionLabel)}
        </a>
      </p>
      <p style="color:#6b625b;font-size:12px;line-height:1.5;margin:0 0 24px;">
        Si el boton no abre, copia este enlace en tu navegador:<br>
        <span style="word-break:break-all;">${escapedLink}</span>
      </p>`
    : `<p style="color:#6b625b;font-size:14px;line-height:1.6;margin:20px 0 24px;">Puedes ver el detalle iniciando sesion en tu portal ${BRAND_NAME}.</p>`;

  const html = `<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(subject)}</title>
  </head>
  <body style="background:#F8F5F0;margin:0;padding:0;">
    <span style="display:none!important;max-height:0;max-width:0;opacity:0;overflow:hidden;">${escapeHtml(preheader)}</span>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F8F5F0;margin:0;padding:24px 0;">
      <tr>
        <td align="center" style="padding:0 16px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#ffffff;border:1px solid #E8DED4;border-radius:8px;max-width:560px;overflow:hidden;">
            <tr>
              <td style="background:#2C2016;color:#ffffff;font-family:Arial,sans-serif;padding:20px 24px;">
                <div style="font-size:18px;font-weight:700;letter-spacing:0;">${BRAND_NAME}</div>
              </td>
            </tr>
            <tr>
              <td style="font-family:Arial,sans-serif;padding:28px 24px;">
                <h1 style="color:#1A1410;font-size:22px;line-height:1.3;margin:0 0 14px;">${escapeHtml(title)}</h1>
                <p style="color:#2C2016;font-size:15px;line-height:1.6;margin:0 0 10px;">${escapeHtml(body)}</p>
                ${actionHtml}
                <p style="border-top:1px solid #E8DED4;color:#6b625b;font-size:12px;line-height:1.5;margin:24px 0 0;padding-top:16px;">
                  Este es un correo transaccional de ${BRAND_NAME}. Por seguridad, los detalles completos se consultan dentro del portal autenticado.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  const text = [
    BRAND_NAME,
    '',
    title,
    '',
    body,
    '',
    appLink ? `${actionLabel}: ${appLink}` : `Puedes ver el detalle iniciando sesion en tu portal ${BRAND_NAME}.`,
    '',
    `Este es un correo transaccional de ${BRAND_NAME}. Por seguridad, los detalles completos se consultan dentro del portal autenticado.`,
  ].join('\n');

  return {subject, html, text};
}
