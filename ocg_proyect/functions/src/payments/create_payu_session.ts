import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {resolvePayuConfig} from './payu_config';
import {loadTreatmentPaymentAccount} from './payu_shared';
import {isAuthorizedPayuCaller} from './payu_webhook_core';

type CreatePayuSessionData = {
  patientId?: string;
  treatmentId?: string;
  monto?: number;
  patientEmail?: string;
  patientName?: string;
};

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

export const createPayuSession = onCall<CreatePayuSessionData>(
  {region: 'us-central1', cors: true},
  async (request: CallableRequest<CreatePayuSessionData>) => {
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
    const authorization = await isAuthorizedPayuCaller({
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
        'No tienes permisos para iniciar pagos PayU para este paciente.',
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

    const payu = resolvePayuConfig();
    const referencia = `OCG-${Date.now()}-${patientId.substring(0, 8)}-${treatmentId.substring(0, 8)}`;
    const montoStr = monto.toFixed(2);

    const signStr = `${payu.apiKey}~${payu.merchantId}~${referencia}~${montoStr}~COP`;
    const signature = crypto.createHash('md5').update(signStr).digest('hex');

    const projectId = process.env.GCLOUD_PROJECT ?? 'TU_PROYECTO';
    const confirmationUrl = `https://us-central1-${projectId}.cloudfunctions.net/payuWebhook`;
    const responseUrl = `${confirmationUrl}?type=response`;

    const buyerEmail = account.patientEmail || normalizeString(request.data?.patientEmail);
    const buyerName = account.patientName || normalizeString(request.data?.patientName) || 'Paciente';

    if (!buyerEmail || !buyerName) {
      throw new HttpsError(
        'failed-precondition',
        'No hay datos suficientes del paciente para iniciar PayU.',
      );
    }

    const params = new URLSearchParams({
      merchantId: payu.merchantId,
      accountId: payu.accountId,
      description: `Pago OCG - ${account.treatmentName}`,
      referenceCode: referencia,
      amount: montoStr,
      tax: '0',
      taxReturnBase: '0',
      currency: 'COP',
      signature,
      responseUrl,
      confirmationUrl,
      buyerEmail,
      buyerFullName: buyerName,
      lng: 'es',
      test: payu.test,
      extra1: patientId,
      extra2: treatmentId,
    });

    const checkoutUrl = `${payu.checkoutUrl}?${params.toString()}`;

    await db.collection('payu_sessions').doc(referencia).set({
      patientId,
      treatmentId,
      monto,
      referencia,
      estado: 'pendiente',
      checkoutUrl,
      entorno: payu.environment,
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
