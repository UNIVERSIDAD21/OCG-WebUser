import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {logger} from 'firebase-functions';

import {resolveEmailRuntimeConfig, isEmailRuntimeReady} from './email_config';
import {resolveEmailRecipient, sendBrevoEmail, maskEmail, configError} from './email_delivery';
import type {EmailFetch} from './email_delivery';
import type {EmailDeliveryResult} from './email_types';

/**
 * Bloque 08: Callable admin para reenviar email de una notificación fallida.
 *
 * Uso (desde el cliente admin):
 *   const result = await resendEmailNotification({ notificationId: '...' });
 *   // { status: 'sent' | 'failed' | 'skipped_...', providerMessageId, error }
 */

interface ResendEmailData {
  /** ID del documento en la colección `notifications`. */
  notificationId: string;
}

interface ResendEmailResult {
  notificationId: string;
  status: string;
  provider: string;
  providerMessageId: string | null;
  error: string | null;
}

export const resendEmailNotification = onCall<ResendEmailData>(
  async (request) => {
    const uid = request.auth?.uid;
    const data = request.data as ResendEmailData;

    if (!uid) {
      throw new HttpsError('unauthenticated', 'Se requiere autenticación.');
    }

    if (!data?.notificationId?.trim()) {
      throw new HttpsError(
        'invalid-argument',
        'notificationId es obligatorio.',
      );
    }

    const db = admin.firestore();
    const notificationId = data.notificationId.trim();

    logger.info('EMAIL_RESEND_REQUEST', {
      adminId: uid,
      notificationId,
    });

    // 1. Leer notificación
    const doc = await db.collection('notifications').doc(notificationId).get();
    if (!doc.exists) {
      throw new HttpsError('not-found', 'Notificación no encontrada.');
    }

    const notification = doc.data() as Record<string, unknown> | undefined;
    if (!notification) {
      throw new HttpsError('internal', 'Datos de notificación inválidos.');
    }

    const recipientId = String(notification.recipientId ?? '');
    const recipientRole = String(notification.recipientRole ?? 'patient');
    const title = String(notification.title ?? '');
    const body = String(notification.body ?? '');
    const type = String(notification.type ?? '');
    const targetRoute = notification.targetRoute
      ? String(notification.targetRoute)
      : null;

    if (!recipientId) {
      throw new HttpsError(
        'invalid-argument',
        'Notificación sin recipientId.',
      );
    }

    // 2. Verificar configuración
    const config = resolveEmailRuntimeConfig();
    if (!isEmailRuntimeReady(config)) {
      const error = configError(config);
      throw new HttpsError('failed-precondition', error.message);
    }

    // 3. Resolver destinatario
    const recipient = await resolveEmailRecipient(
      db,
      recipientRole as 'admin' | 'patient',
      recipientId,
    );
    if (!recipient.ok) {
      throw new HttpsError('not-found', `Sin email válido: ${recipient.reason}`);
    }

    // 4. Enviar
    const payload = {
      notificationId,
      recipientId,
      recipientRole: recipientRole as 'admin' | 'patient',
      title,
      body,
      type,
      targetRoute: targetRoute ?? undefined,
      source: 'admin_resend',
    };

    let result: EmailDeliveryResult;
    if (config.provider === 'brevo') {
      result = await sendBrevoEmail({
        config,
        payload,
        to: recipient.recipient.email,
        fetchImpl: fetch as EmailFetch,
      });
    } else {
      throw new HttpsError(
        'unimplemented',
        `Provider ${config.provider} no soportado para reenvío.`,
      );
    }

    // 5. Actualizar historial
    await db.collection('notifications').doc(notificationId).set(
      {
        emailStatus: result.status,
        emailTo: result.to ?? null,
        emailProvider: result.provider,
        emailProviderMessageId: result.providerMessageId ?? null,
        emailAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
        emailError: result.error ?? null,
        emailResentBy: uid,
        emailResentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    const response: ResendEmailResult = {
      notificationId,
      status: result.status,
      provider: result.provider,
      providerMessageId: result.providerMessageId,
      error: result.error?.message ?? null,
    };

    logger.info('EMAIL_RESEND_COMPLETE', {
      notificationId,
      status: result.status,
      recipientPreview: maskEmail(recipient.recipient.email),
    });

    return response;
  },
);
