import type {EmailNotificationPayload} from './email_types';

export interface RenderedEmailTemplate {
  subject: string;
  html: string;
  text: string;
}

export interface RenderEmailTemplateOptions {
  appLink?: string | null;
}

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
      return 'OCG Clinica - Pago recibido';
    case 'payment_due':
      return 'OCG Clinica - Pago proximo a vencer';
    case 'payment_due_soon':
      return 'OCG Clinica - Pago proximo a vencer';
    case 'payment_overdue':
      return 'OCG Clinica - Pago vencido';
    case 'payment_failed':
      return 'OCG Clinica - Pago no aprobado';
    case 'payment_pending_validation':
      return 'OCG Clinica - Pago pendiente de validacion';
    case 'payment_reported':
      return 'OCG Clinica - Nuevo pago reportado';
    case 'treatment_stage_updated':
      return 'OCG Clinica - Tu tratamiento avanzo';
    case 'appointment_created':
      return 'OCG Clinica - Nueva cita';
    case 'appointment_confirmed':
      return 'OCG Clinica - Cita confirmada';
    case 'appointment_cancelled':
      return 'OCG Clinica - Cita cancelada';
    case 'appointment_rescheduled':
      return 'OCG Clinica - Cita reprogramada';
    case 'appointment_reminder':
      return 'OCG Clinica - Recordatorio de cita';
    case 'appointment_pending_confirmation':
      return 'OCG Clinica - Cita pendiente de confirmacion';
    default:
      return normalize(payload.title) || 'OCG Clinica - Notificacion';
  }
}

function preheaderForType(type: string): string {
  if (type === 'payment' || type.startsWith('payment_') || type.includes('pago')) {
    return 'Actualizacion importante sobre pagos en OCG Clinica.';
  }
  if (type === 'treatment_stage_updated') {
    return 'Actualizacion sobre el avance de tu tratamiento.';
  }
  if (type.startsWith('appointment_')) {
    return 'Actualizacion importante sobre tu cita.';
  }
  return 'Tienes una nueva notificacion de OCG Clinica.';
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
  const body = normalize(payload.body) || 'Tienes una nueva notificacion de OCG Clinica.';
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
    : '<p style="color:#6b625b;font-size:14px;line-height:1.6;margin:20px 0 24px;">Puedes ver el detalle iniciando sesion en tu portal OCG.</p>';

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
                <div style="font-size:18px;font-weight:700;letter-spacing:0;">OCG Clinica</div>
              </td>
            </tr>
            <tr>
              <td style="font-family:Arial,sans-serif;padding:28px 24px;">
                <h1 style="color:#1A1410;font-size:22px;line-height:1.3;margin:0 0 14px;">${escapeHtml(title)}</h1>
                <p style="color:#2C2016;font-size:15px;line-height:1.6;margin:0 0 10px;">${escapeHtml(body)}</p>
                ${actionHtml}
                <p style="border-top:1px solid #E8DED4;color:#6b625b;font-size:12px;line-height:1.5;margin:24px 0 0;padding-top:16px;">
                  Este es un correo transaccional de OCG Clinica. Por seguridad, los detalles completos se consultan dentro del portal autenticado.
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
    'OCG Clinica',
    '',
    title,
    '',
    body,
    '',
    appLink ? `${actionLabel}: ${appLink}` : 'Puedes ver el detalle iniciando sesion en tu portal OCG.',
    '',
    'Este es un correo transaccional de OCG Clinica. Por seguridad, los detalles completos se consultan dentro del portal autenticado.',
  ].join('\n');

  return {subject, html, text};
}
