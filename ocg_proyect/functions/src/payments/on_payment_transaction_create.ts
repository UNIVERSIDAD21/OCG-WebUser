import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {logger} from 'firebase-functions';

import * as admin from 'firebase-admin';

import {
  formatCop,
  notifyPatientPaymentEvent,
} from '../notifications/domain_notifications';
import {loadTreatmentPaymentAccount} from './epayco_shared';

function normalize(value: unknown): string {
  return String(value ?? '').trim();
}

function normalizeNumber(value: unknown): number {
  const amount = typeof value === 'number' ? value : Number(value ?? NaN);
  return Number.isFinite(amount) ? amount : 0;
}

function asDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function pickTreatmentName(
  treatmentId: string,
  account: Awaited<ReturnType<typeof loadTreatmentPaymentAccount>> | null,
  treatmentData: Record<string, unknown>,
): string {
  const fromAccount = normalize(account?.treatmentName);
  if (fromAccount) return fromAccount;

  return (
    normalize(treatmentData.visibleName) ||
    normalize(treatmentData.clinicalTreatmentName) ||
    normalize(treatmentData.name) ||
    normalize(treatmentData.nombre) ||
    treatmentId ||
    'tu tratamiento'
  );
}

function isGatewayOrBackfillTransaction(
  transactionId: string,
  data: Record<string, unknown>,
): boolean {
  const method = normalize(data.metodo).toLowerCase();
  const registeredBy = normalize(data.registradoPor).toLowerCase();
  return (
    method === 'epayco' ||
    registeredBy === 'epayco_webhook' ||
    transactionId.startsWith('epayco_') ||
    normalize(data.epaycoOrderId).length > 0 ||
    normalize(data.epaycoTransactionId).length > 0 ||
    data.legacySource === true ||
    normalize(data.migratedFrom).length > 0
  );
}

export async function handlePaymentTransactionCreate(
  db: FirebaseFirestore.Firestore,
  params: {
    patientId: string;
    treatmentId: string;
    transactionId: string;
  },
  data: Record<string, unknown>,
): Promise<'notified' | 'skipped'> {
  const patientId = normalize(params.patientId);
  const treatmentId = normalize(params.treatmentId);
  const transactionId = normalize(params.transactionId);
  const amount = normalizeNumber(data.monto);

  if (!patientId || !treatmentId || !transactionId || amount <= 0) {
    logger.warn('Skipping manual payment notification: invalid transaction payload', {
      patientId,
      treatmentId,
      transactionId,
      amount,
    });
    return 'skipped';
  }

  if (isGatewayOrBackfillTransaction(transactionId, data)) {
    logger.info('Skipping manual payment notification: gateway/backfill transaction', {
      patientId,
      treatmentId,
      transactionId,
      metodo: normalize(data.metodo) || null,
      registradoPor: normalize(data.registradoPor) || null,
    });
    return 'skipped';
  }

  const [account, treatmentSnap, paymentSnap] = await Promise.all([
    loadTreatmentPaymentAccount(db, patientId, treatmentId),
    db.collection('patients').doc(patientId).collection('treatments').doc(treatmentId).get(),
    db
      .collection('payments')
      .doc(patientId)
      .collection('treatments')
      .doc(treatmentId)
      .get(),
  ]);

  if (!account) {
    logger.warn('Manual payment notification continuing with fallback data: payment account not found', {
      patientId,
      treatmentId,
      transactionId,
    });
  }

  const payment = paymentSnap.data() ?? {};
  const remainingBalance = normalizeNumber(payment.saldoPendiente);
  const dueDate = asDate(payment.fechaProximoPago);
  const reference = normalize(data.referencia) || transactionId;
  const treatmentName = pickTreatmentName(
    treatmentId,
    account,
    treatmentSnap.data() ?? {},
  );
  const body = paymentSnap.exists
    ? `Registramos tu pago por ${formatCop(amount)} para ${treatmentName}. Tu saldo pendiente ahora es ${formatCop(remainingBalance)}.`
    : `Registramos tu pago por ${formatCop(amount)} para ${treatmentName}.`;

  await notifyPatientPaymentEvent(db, {
    notificationId: `manual_payment_received_${transactionId}`,
    patientId,
    paymentId: treatmentId,
    treatmentId,
    type: 'payment_received',
    title: 'Pago registrado',
    body,
    amount,
    dueDate: dueDate ?? undefined,
    reference,
  });

  logger.info('Manual payment notification delivered', {
    patientId,
    treatmentId,
    transactionId,
    amount,
    remainingBalance,
  });

  return 'notified';
}

export const onPaymentTransactionCreate = onDocumentCreated(
  {
    region: 'us-central1',
    document: 'payments/{patientId}/treatments/{treatmentId}/transactions/{transactionId}',
  },
  async (event) => {
    await handlePaymentTransactionCreate(
      admin.firestore(),
      {
        patientId: event.params.patientId,
        treatmentId: event.params.treatmentId,
        transactionId: event.params.transactionId,
      },
      event.data?.data() ?? {},
    );
  },
);
