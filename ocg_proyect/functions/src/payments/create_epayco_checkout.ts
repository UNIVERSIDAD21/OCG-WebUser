import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {resolveEpaycoConfig} from './epayco_config';
import {loadTreatmentPaymentAccount} from './epayco_shared';
import {isAuthorizedEpaycoCaller} from './epayco_webhook_core';

type CreateEpaycoCheckoutData = {
  patientId?: string;
  treatmentId?: string;
  monto?: number;
  patientEmail?: string;
  patientName?: string;
};

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

export const createEpaycoCheckout = onCall<CreateEpaycoCheckoutData>(
  {region: 'us-central1', cors: true},
  async (request: CallableRequest<CreateEpaycoCheckoutData>) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const patientId = normalizeString(request.data?.patientId);
    const treatmentId = normalizeString(request.data?.treatmentId);
    const monto = Number(request.data?.monto ?? 0);

    if (!patientId || !treatmentId || !Number.isFinite(monto) || monto <= 0) {
      throw new HttpsError(
        'invalid-argument',
        'Debes enviar patientId, treatmentId y monto válidos.',
      );
    }

    const db = admin.firestore();
    const authorization = await isAuthorizedEpaycoCaller({
      db,
      auth: request.auth
        ? {
            uid: request.auth.uid,
            token: request.auth.token as Record<string, unknown>,
          }
        : null,
      patientId,
    });

    if (!authorization.allowed) {
      throw new HttpsError(
        'permission-denied',
        'No tienes permisos para iniciar pagos para este paciente.',
      );
    }

    const account = await loadTreatmentPaymentAccount(db, patientId, treatmentId);

    if (!account) {
      throw new HttpsError(
        'failed-precondition',
        'No existe el tratamiento o la cuenta de cobro asociada.',
      );
    }

    if (account.saldoPendiente <= 0) {
      throw new HttpsError(
        'failed-precondition',
        'La cuenta seleccionada ya no tiene saldo pendiente.',
      );
    }

    if (monto > account.saldoPendiente) {
      throw new HttpsError(
        'failed-precondition',
        'El monto no puede superar el saldo pendiente del tratamiento.',
      );
    }

    const epayco = resolveEpaycoConfig();
    const referencia = `OCG-${Date.now()}-${patientId.substring(0, 8)}-${treatmentId.substring(0, 8)}`;
    const montoStr = monto.toFixed(2);

    // Epayco signature: SHA256(privateKey + customerId + referenceCode + amount)
    const signStr = `${epayco.privateKey}${epayco.customerId}${referencia}${montoStr}`;
    const signature = crypto.createHash('sha256').update(signStr).digest('hex');

    const projectId = process.env.GCLOUD_PROJECT ?? 'TU_PROYECTO';
    const confirmationUrl = `https://us-central1-${projectId}.cloudfunctions.net/epaycoWebhook`;
    const responseUrl = `${confirmationUrl}?type=response`;

    const buyerEmail = account.patientEmail || normalizeString(request.data?.patientEmail);
    const buyerName = account.patientName || normalizeString(request.data?.patientName) || 'Paciente';

    if (!buyerEmail || !buyerName) {
      throw new HttpsError(
        'failed-precondition',
        'No hay datos suficientes del paciente para iniciar el pago.',
      );
    }

    // Build Epayco checkout URL with form parameters
    const params = new URLSearchParams({
      epayco_public_key: epayco.publicKey,
      epayco_customer_id: epayco.customerId,
      epayco_reference: referencia,
      epayco_description: `Pago OCG - ${account.treatmentName}`,
      epayco_amount: montoStr,
      epayco_currency: 'COP',
      epayco_email_buyer: buyerEmail,
      epayco_name_buyer: buyerName,
      epayco_confirmation_url: confirmationUrl,
      epayco_response_url: responseUrl,
      epayco_signature: signature,
      epayco_test: epayco.test ? 'TRUE' : 'FALSE',
      epayco_lang: 'es',
      epayco_country: 'CO',
    });

    const checkoutUrl = `${epayco.checkoutUrl}?${params.toString()}`;

    // Store session (using 'payu_sessions' collection for backwards compatibility)
    await db.collection('payu_sessions').doc(referencia).set({
      patientId,
      treatmentId,
      monto,
      referencia,
      estado: 'pendiente',
      checkoutUrl,
      entorno: epayco.environment,
      gateway: 'epayco',
      patientEmail: buyerEmail,
      patientName: buyerName,
      initiatedBy: {
        uid: request.auth.uid,
        role: authorization.role,
      },
      treatmentSnapshot: {
        treatmentName: account.treatmentName,
        saldoPendiente: account.saldoPendiente,
        treatmentIsPrimary: account.treatmentIsPrimary,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {checkoutUrl, referencia, treatmentId};
  },
);
