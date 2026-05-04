import * as admin from 'firebase-admin';

import {formatCop, notifyAdminPaymentEvent, notifyPatientPaymentEvent} from '../notifications/domain_notifications';
import {PaymentAccountSnapshot, loadTreatmentPaymentAccount, normalizePayuState} from './payu_shared';
import {PayuResolvedConfig} from './payu_config';
import {PayuSessionRecord, PayuWebhookPayload, PayuWebhookResult} from './payu_types';

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

function normalizeNumber(value: unknown): number {
  return typeof value === 'number' ? value : Number(value ?? 0);
}

function sameAmount(a: number, b: number, tolerance = 0.01): boolean {
  return Math.abs(a - b) <= tolerance;
}

function isAdminToken(token: Record<string, unknown> | undefined): boolean {
  return token?.role === 'admin' || token?.admin === true;
}

export async function isAuthorizedPayuCaller(params: {
  db: admin.firestore.Firestore;
  auth: {uid: string; token?: Record<string, unknown>} | null | undefined;
  patientId: string;
}): Promise<{allowed: true; role: 'patient' | 'admin'} | {allowed: false}> {
  const auth = params.auth;
  if (!auth?.uid) return {allowed: false};
  if (auth.uid === params.patientId) return {allowed: true, role: 'patient'};
  if (isAdminToken(auth.token)) return {allowed: true, role: 'admin'};
  const adminDoc = await params.db.collection('admins').doc(auth.uid).get();
  if (adminDoc.exists) return {allowed: true, role: 'admin'};
  return {allowed: false};
}

export function buildPayuDeterministicTxId(reference: string): string {
  return `payu_${reference}`;
}

function isApprovedState(state: string): boolean {
  return normalizeString(state) === 'aprobado';
}

async function markSessionError(
  sessionRef: admin.firestore.DocumentReference,
  errorCode: string,
  errorDetail: string,
): Promise<PayuWebhookResult> {
  await sessionRef.set(
    {
      estado: 'error_controlado',
      errorCode,
      errorDetail,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  return {ok: true, action: 'error_recorded', sessionState: 'error_controlado'};
}

function buildUpdatedPaymentState(params: {
  saldoActual: number;
  montoActualPagado: number;
  montoAplicado: number;
  fechaProximoPago: Date | null;
}): {nuevoSaldo: number; nuevoPagado: number; nuevoEstado: string} {
  const nuevoSaldo = Math.max(0, params.saldoActual - params.montoAplicado);
  const nuevoPagado = params.montoActualPagado + params.montoAplicado;
  const now = new Date();
  const fecha = params.fechaProximoPago;
  const nuevoEstado =
    nuevoSaldo <= 0
      ? 'pagadoTotal'
      : !fecha
        ? 'pendiente'
        : fecha.getTime() < now.getTime()
          ? 'vencido'
          : fecha.getTime() <= now.getTime() + 7 * 24 * 60 * 60 * 1000
            ? 'pendiente'
            : 'alDia';
  return {nuevoSaldo, nuevoPagado, nuevoEstado};
}

async function processNonApprovedState(params: {
  db: admin.firestore.Firestore;
  sessionRef: admin.firestore.DocumentReference;
  session: PayuSessionRecord;
  payload: PayuWebhookPayload;
  account: PaymentAccountSnapshot;
  notifyAdminPayment: typeof notifyAdminPaymentEvent;
}): Promise<PayuWebhookResult> {
  const currentState = normalizeString(params.session.estado);
  if (currentState === 'aprobado') {
    return {ok: true, action: 'ignored_terminal_approved', sessionState: 'aprobado'};
  }

  const nextState = normalizePayuState(params.payload.statePol);
  await params.sessionRef.set(
    {
      estado: nextState,
      payuOrderId: params.payload.payuOrderId,
      payuTransactionId: params.payload.payuTransactionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (params.payload.statePol === 6 || params.payload.statePol === 7) {
    await params.notifyAdminPayment(params.db, {
      notificationId: `admin_${nextState}_${params.payload.reference}`,
      patientId: params.account.patientId,
      patientName: params.account.patientName,
      paymentId: params.account.treatmentId,
      treatmentId: params.account.treatmentId,
      transactionId: params.payload.payuTransactionId,
      type: params.payload.statePol === 6 ? 'payment_failed' : 'payment_pending_validation',
      title: params.payload.statePol === 6 ? 'Pago rechazado' : 'Pago pendiente de validación',
      body:
        params.payload.statePol === 6
          ? `El pago de ${params.account.patientName} para ${params.account.treatmentName} por ${formatCop(params.session.monto)} fue rechazado o falló.`
          : `Hay un pago de ${params.account.patientName} para ${params.account.treatmentName} pendiente por validar.`,
      amount: params.session.monto,
      reference: params.payload.reference,
      sourceRole: 'system',
      sendPush: true,
    });
  }

  return {ok: true, action: 'non_approved_recorded', sessionState: nextState};
}

export async function processPayuWebhook(params: {
  db: admin.firestore.Firestore;
  payu: PayuResolvedConfig;
  payload: PayuWebhookPayload;
  notifyPatientPayment?: typeof notifyPatientPaymentEvent;
  notifyAdminPayment?: typeof notifyAdminPaymentEvent;
}): Promise<PayuWebhookResult> {
  const {db, payu, payload} = params;
  const notifyPatientPayment = params.notifyPatientPayment ?? notifyPatientPaymentEvent;
  const notifyAdminPayment = params.notifyAdminPayment ?? notifyAdminPaymentEvent;
  const sessionRef = db.collection('payu_sessions').doc(payload.reference);
  const sessionSnap = await sessionRef.get();

  if (!sessionSnap.exists) {
    return {ok: true, action: 'ignored_missing_session'};
  }

  const session = (sessionSnap.data() ?? {}) as PayuSessionRecord;
  const patientId = normalizeString(session.patientId);
  const treatmentId = normalizeString(session.treatmentId);
  const montoSesion = normalizeNumber(session.monto);

  if (!patientId || !treatmentId || !Number.isFinite(montoSesion) || montoSesion <= 0) {
    return markSessionError(sessionRef, 'invalid_session', 'La sesión no contiene patientId, treatmentId o monto válidos.');
  }

  if (payload.merchantId !== payu.merchantId) {
    return markSessionError(sessionRef, 'merchant_mismatch', 'merchant_id diferente al configurado.');
  }

  if (payload.currency !== 'COP') {
    return markSessionError(sessionRef, 'currency_mismatch', 'La moneda recibida no es COP.');
  }

  if (!sameAmount(payload.value, montoSesion)) {
    return markSessionError(sessionRef, 'amount_mismatch', 'El valor recibido por PayU no coincide con el monto de la sesión.');
  }

  const account = await loadTreatmentPaymentAccount(db, patientId, treatmentId);
  if (!account) {
    return markSessionError(sessionRef, 'missing_account', 'No existe la cuenta de pago del tratamiento.');
  }

  if (payload.statePol !== 4) {
    return processNonApprovedState({db, sessionRef, session, payload, account, notifyAdminPayment});
  }

  const txId = buildPayuDeterministicTxId(payload.reference);
  const treatmentPaymentRef = db.collection('payments').doc(patientId).collection('treatments').doc(treatmentId);
  const treatmentTransactionRef = treatmentPaymentRef.collection('transactions').doc(txId);
  const treatmentRef = db.collection('patients').doc(patientId).collection('treatments').doc(treatmentId);
  const legacyPaymentRef = db.collection('payments').doc(patientId);
  const patientRef = db.collection('patients').doc(patientId);

  const approval = await db.runTransaction(async (transaction) => {
    const [freshSessionSnap, paymentSnap, existingTxSnap, treatmentSnap, legacySnap] = await Promise.all([
      transaction.get(sessionRef),
      transaction.get(treatmentPaymentRef),
      transaction.get(treatmentTransactionRef),
      transaction.get(treatmentRef),
      transaction.get(legacyPaymentRef),
    ]);

    const freshSession = (freshSessionSnap.data() ?? {}) as PayuSessionRecord;
    const freshState = normalizeString(freshSession.estado);
    if (freshState === 'aprobado') {
      return {kind: 'already-approved' as const};
    }

    if (!paymentSnap.exists || !treatmentSnap.exists) {
      transaction.set(sessionRef, {
        estado: 'error_controlado',
        errorCode: 'missing_account_transaction',
        errorDetail: 'La cuenta/tratamiento no existe al momento de aplicar el pago.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {kind: 'error' as const, state: 'error_controlado'};
    }

    if (existingTxSnap.exists) {
      transaction.set(sessionRef, {
        estado: 'aprobado',
        payuOrderId: payload.payuOrderId,
        payuTransactionId: payload.payuTransactionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {kind: 'already-applied' as const};
    }

    const payment = paymentSnap.data() ?? {};
    const saldoActual = normalizeNumber(payment.saldoPendiente);
    const montoActualPagado = normalizeNumber(payment.montoPagado);
    if (montoSesion > saldoActual) {
      transaction.set(sessionRef, {
        estado: 'error_controlado',
        errorCode: 'amount_exceeds_balance',
        errorDetail: 'El monto de la sesión supera el saldo pendiente real.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {kind: 'error' as const, state: 'error_controlado'};
    }

    const fechaProximoPago =
      payment.fechaProximoPago instanceof admin.firestore.Timestamp
        ? payment.fechaProximoPago.toDate()
        : null;
    const {nuevoSaldo, nuevoPagado, nuevoEstado} = buildUpdatedPaymentState({
      saldoActual,
      montoActualPagado,
      montoAplicado: montoSesion,
      fechaProximoPago,
    });

    const paymentCreatedAt = payment.createdAt ?? admin.firestore.FieldValue.serverTimestamp();

    transaction.create(treatmentTransactionRef, {
      id: txId,
      patientId,
      treatmentId,
      monto: montoSesion,
      fecha: admin.firestore.FieldValue.serverTimestamp(),
      metodo: 'payu',
      referencia: payload.reference,
      registradoPor: 'payu_webhook',
      notas: 'Pago procesado por PayU Colombia',
      reciboUrl: null,
      payuOrderId: payload.payuOrderId,
      payuTransactionId: payload.payuTransactionId,
    });

    transaction.set(treatmentPaymentRef, {
      id: treatmentId,
      patientId,
      treatmentId,
      totalTratamiento: normalizeNumber(payment.totalTratamiento),
      montoPagado: nuevoPagado,
      saldoPendiente: nuevoSaldo,
      estado: nuevoEstado,
      fechaProximoPago: payment.fechaProximoPago ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: paymentCreatedAt,
      schemaVersion: 2,
    }, {merge: true});

    transaction.set(treatmentRef, {
      saldoPendiente: nuevoSaldo,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'financialSummary.paidAmount': nuevoPagado,
      'financialSummary.pendingAmount': nuevoSaldo,
    }, {merge: true});

    if (account.treatmentIsPrimary) {
      const legacyData = legacySnap.data() ?? {};
      transaction.set(legacyPaymentRef, {
        id: patientId,
        patientId,
        treatmentId,
        totalTratamiento: normalizeNumber(payment.totalTratamiento),
        montoPagado: nuevoPagado,
        saldoPendiente: nuevoSaldo,
        estado: nuevoEstado,
        fechaProximoPago: payment.fechaProximoPago ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: legacyData.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
        schemaVersion: 1,
        legacyMirror: true,
      }, {merge: true});

      transaction.set(patientRef, {
        primaryTreatmentId: treatmentId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'treatmentOverview.financial.totalTratamiento': normalizeNumber(payment.totalTratamiento),
        'treatmentOverview.financial.montoPagado': nuevoPagado,
        'treatmentOverview.financial.saldoPendiente': nuevoSaldo,
        'treatmentOverview.source': 'treatment-truth',
        'legacyProjection.financialSource': 'compatibility-only',
      }, {merge: true});
    }

    transaction.set(sessionRef, {
      estado: 'aprobado',
      payuOrderId: payload.payuOrderId,
      payuTransactionId: payload.payuTransactionId,
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {kind: 'applied' as const, nuevoSaldo, appliedAmount: montoSesion, txId, dueDate: fechaProximoPago};
  });

  if (approval.kind === 'error') {
    return {ok: true, action: 'error_recorded', sessionState: approval.state};
  }

  if (approval.kind === 'already-approved') {
    return {ok: true, action: 'ignored_terminal_approved', sessionState: 'aprobado'};
  }

  if (approval.kind === 'already-applied') {
    return {ok: true, action: 'approved_already_applied', sessionState: 'aprobado', transactionId: txId};
  }

  await notifyPatientPayment(db, {
    notificationId: `payment_received_${payload.reference}`,
    patientId,
    paymentId: treatmentId,
    treatmentId,
    type: 'payment_received',
    title: 'Pago recibido con éxito',
    body: `Recibimos tu pago por ${formatCop(approval.appliedAmount)} para ${account.treatmentName}. Tu saldo pendiente ahora es ${formatCop(approval.nuevoSaldo)}.`,
    amount: approval.appliedAmount,
    dueDate: approval.dueDate ?? undefined,
    reference: payload.reference,
  });

  await notifyAdminPayment(db, {
    notificationId: `admin_payment_reported_${payload.reference}`,
    patientId,
    patientName: account.patientName,
    paymentId: treatmentId,
    treatmentId,
    transactionId: approval.txId,
    type: 'payment_reported',
    title: 'Nuevo pago reportado',
    body: `${account.patientName} reportó un pago por ${formatCop(approval.appliedAmount)} para ${account.treatmentName}.`,
    amount: approval.appliedAmount,
    dueDate: approval.dueDate ?? undefined,
    reference: payload.reference,
    sourceRole: 'patient',
    sourceUserId: patientId,
    sendPush: true,
  });

  return {
    ok: true,
    action: 'approved_applied',
    sessionState: 'aprobado',
    transactionId: approval.txId,
    appliedAmount: approval.appliedAmount,
  };
}
