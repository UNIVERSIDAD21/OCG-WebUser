import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type CreatePayuSessionData = {
  patientId?: string;
  monto?: number;
  patientEmail?: string;
  patientName?: string;
};

const SANDBOX = {
  apiKey: '4Vj8eK4rloUd272L48hsrarnUA',
  merchantId: '508029',
  accountId: '512321',
  checkoutUrl: 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/',
};

export const createPayuSession = onCall<CreatePayuSessionData>(
  {region: 'us-central1', cors: true},
  async (request: CallableRequest<CreatePayuSessionData>) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const patientId = request.data?.patientId?.trim() ?? '';
    const monto = Number(request.data?.monto ?? 0);
    const patientEmail = request.data?.patientEmail?.trim() ?? '';
    const patientName = request.data?.patientName?.trim() ?? '';

    if (!patientId || !patientEmail || !patientName || !Number.isFinite(monto) || monto <= 0) {
      throw new HttpsError('invalid-argument', 'Parámetros inválidos.');
    }

    const referencia = `OCG-${Date.now()}-${patientId.substring(0, 8)}`;
    const montoStr = monto.toFixed(2);

    const signStr = `${SANDBOX.apiKey}~${SANDBOX.merchantId}~${referencia}~${montoStr}~COP`;
    const signature = crypto.createHash('md5').update(signStr).digest('hex');

    const projectId = process.env.GCLOUD_PROJECT ?? 'TU_PROYECTO';
    const confirmationUrl = `https://us-central1-${projectId}.cloudfunctions.net/payuWebhook`;
    const responseUrl = `${confirmationUrl}?type=response`;

    const params = new URLSearchParams({
      merchantId: SANDBOX.merchantId,
      accountId: SANDBOX.accountId,
      description: 'Tratamiento de ortodoncia - OCG Clínica',
      referenceCode: referencia,
      amount: montoStr,
      tax: '0',
      taxReturnBase: '0',
      currency: 'COP',
      signature,
      responseUrl,
      confirmationUrl,
      buyerEmail: patientEmail,
      buyerFullName: patientName,
      lng: 'es',
      test: '1',
    });

    const checkoutUrl = `${SANDBOX.checkoutUrl}?${params.toString()}`;

    await admin.firestore().collection('payu_sessions').doc(referencia).set({
      patientId,
      monto,
      referencia,
      estado: 'pendiente',
      checkoutUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {checkoutUrl, referencia};
  },
);
