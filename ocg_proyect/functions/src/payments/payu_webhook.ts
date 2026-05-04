import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import {onRequest} from 'firebase-functions/v2/https';

import {formatCop, notifyAdminPaymentEvent, notifyPatientPaymentEvent} from '../notifications/domain_notifications';
import {resolvePayuConfig} from './payu_config';
import {loadTreatmentPaymentAccount, normalizePayuState} from './payu_shared';

type PayuSessionRecord = {
  patientId?: string;
  treatmentId?: string;
  monto?: number;
  estado?: string;
  checkoutUrl?: string;
  entorno?: string;
  patientEmail?: string;
  patientName?: string;
};

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

function normalizeNumber(value: unknown): number {
  return typeof value === 'number' ? value : Number(value ?? 0);
}

export const payuWebhook = onRequest({region: 'us-central1', cors: false}, async (req, res) => {
  try {
    const body = req.body ?? {};
    const payu = resolvePayuConfig();

    const reference = normalizeString(body.reference_sale);
    const merchantId = normalizeString(body.merchant_id);
    const value = normalizeNumber(body.value);
    const currency = normalizeString(body.currency || 'COP');
    const statePol = normalizeString(body.state_pol);
    const sign = normalizeString(body.sign).toLowerCase();

    const signRaw = [
      payu.apiKey,
      merchantId,
      reference,
      value.toFixed(1),
      currency,
      statePol,
    ].join('~');

    const expectedSign = crypto.createHash('md5').update(signRaw).digest('hex').toLowerCase();

    if (expectedSign !== sign) {
      console.error('payuWebhook firma inválida', {reference, provided: sign, expected: expectedSign});
      res.status(401).send('Firma inválida');
      return;
    }

    const db = admin.firestore();
    const sessionRef = db.collection('payu_sessions').doc(reference);
    const sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      console.error('payuWebhook referencia no encontrada', {reference});
      res.status(200).send('OK');
      return;
    }

    const session = (sessionSnap.data() ?? {}) as PayuSessionRecord;
    const patientId = normalizeString(session.patientId);
    const treatmentId = normalizeString(session.treatmentId);
    const montoSesion = normalizeNumber(session.monto);
    const state = Number(statePol);
    const normalizedState = normalizePayuState(state);

    if (!patientId || !treatmentId || !Number.isFinite(montoSesion) || montoSesion <= 0) {
      console.error('payuWebhook sesión inválida', {reference, patientId, treatmentId, montoSesion});
      await sessionRef.set(
        {
          estado: 'error_sesion',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      res.status(200).send('OK');
      return;
    }

    const account = await loadTreatmentPaymentAccount(db, patientId, treatmentId);
    if (!account) {
      console.error('payuWebhook cuenta/tratamiento no encontrado', {reference, patientId, treatmentId});
      await sessionRef.set(
        {
          estado: 'error_payment_doc',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      res.status(200).send('OK');
      return;
    }

    const payuOrderId = normalizeString(body.order_id);
    const payuTransactionId = normalizeString(body.transaction_id);
    const txId = payuTransactionId.length > 0 ? payuTransactionId : `payu-${reference}`;
    const treatmentPaymentRef = db
      .collection('payments')
      .doc(patientId)
      .collection('treatments')
      .doc(treatmentId);
    const treatmentTransactionRef = treatmentPaymentRef.collection('transactions').doc(txId);
    const treatmentRef = db.collection('patients').doc(patientId).collection('treatments').doc(treatmentId);
    const legacyPaymentRef = db.collection('payments').doc(patientId);
    const patientRef = db.collection('patients').doc(patientId);

    if (state === 4) {
      if (normalizeString(session.estado) === 'aprobado') {
        res.status(200).send('OK');
        return;
      }

      const existingTx = await treatmentTransactionRef.get();
      if (existingTx.exists) {
        await sessionRef.set(
          {
            estado: 'aprobado',
            payuOrderId,
            payuTransactionId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        res.status(200).send('OK');
        return;
      }

      const saldoActual = account.saldoPendiente;
      const montoActualPagado = account.montoPagado;
      const appliedMonto = Math.min(montoSesion, Math.max(saldoActual, 0));

      if (appliedMonto <= 0) {
        await sessionRef.set(
          {
            estado: 'aprobado_sin_aplicacion',
            payuOrderId,
            payuTransactionId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        res.status(200).send('OK');
        return;
      }

      const nuevoSaldo = Math.max(0, saldoActual - appliedMonto);
      const nuevoPagado = montoActualPagado + appliedMonto;
      const fechaProximoPago = account.fechaProximoPago?.toDate() ?? null;
      const now = new Date();
      const nuevoEstado =
        nuevoSaldo <= 0
          ? 'pagadoTotal'
          : !fechaProximoPago
            ? 'pendiente'
            : fechaProximoPago.getTime() < now.getTime()
              ? 'vencido'
              : fechaProximoPago.getTime() <= now.getTime() + 7 * 24 * 60 * 60 * 1000
                ? 'pendiente'
                : 'alDia';

      const batch = db.batch();
      batch.set(treatmentTransactionRef, {
        id: txId,
        patientId,
        treatmentId,
        monto: appliedMonto,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        metodo: 'payu',
        referencia: reference,
        registradoPor: 'payu_webhook',
        notas: 'Pago procesado por PayU Colombia',
        reciboUrl: null,
        payuOrderId,
        payuTransactionId,
      }, {merge: false});

      batch.set(
        treatmentPaymentRef,
        {
          id: treatmentId,
          patientId,
          treatmentId,
          totalTratamiento: account.totalTratamiento,
          montoPagado: nuevoPagado,
          saldoPendiente: nuevoSaldo,
          estado: nuevoEstado,
          fechaProximoPago: account.fechaProximoPago,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          schemaVersion: 2,
        },
        {merge: true},
      );

      batch.set(
        treatmentRef,
        {
          saldoPendiente: nuevoSaldo,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'financialSummary.paidAmount': nuevoPagado,
          'financialSummary.pendingAmount': nuevoSaldo,
        },
        {merge: true},
      );

      if (account.treatmentIsPrimary) {
        batch.set(
          legacyPaymentRef,
          {
            id: patientId,
            patientId,
            treatmentId,
            totalTratamiento: account.totalTratamiento,
            montoPagado: nuevoPagado,
            saldoPendiente: nuevoSaldo,
            estado: nuevoEstado,
            fechaProximoPago: account.fechaProximoPago,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            schemaVersion: 1,
            legacyMirror: true,
          },
          {merge: true},
        );

        batch.set(
          patientRef,
          {
            primaryTreatmentId: treatmentId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'treatmentOverview.financial.totalTratamiento': account.totalTratamiento,
            'treatmentOverview.financial.montoPagado': nuevoPagado,
            'treatmentOverview.financial.saldoPendiente': nuevoSaldo,
            'treatmentOverview.source': 'treatment-truth',
            'legacyProjection.financialSource': 'compatibility-only',
          },
          {merge: true},
        );
      }

      batch.set(
        sessionRef,
        {
          estado: 'aprobado',
          payuOrderId,
          payuTransactionId,
          appliedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      await batch.commit();

      await notifyPatientPaymentEvent(db, {
        notificationId: `payment_received_${reference}`,
        patientId,
        paymentId: treatmentId,
        treatmentId,
        type: 'payment_received',
        title: 'Pago recibido con éxito',
        body: `Recibimos tu pago por ${formatCop(appliedMonto)} para ${account.treatmentName}. Tu saldo pendiente ahora es ${formatCop(nuevoSaldo)}.`,
        amount: appliedMonto,
        dueDate: fechaProximoPago ?? undefined,
        reference,
      });

      await notifyAdminPaymentEvent(db, {
        notificationId: `admin_payment_reported_${reference}`,
        patientId,
        patientName: account.patientName,
        paymentId: treatmentId,
        treatmentId,
        transactionId: txId,
        type: 'payment_reported',
        title: 'Nuevo pago reportado',
        body: `${account.patientName} reportó un pago por ${formatCop(appliedMonto)} para ${account.treatmentName}.`,
        amount: appliedMonto,
        dueDate: fechaProximoPago ?? undefined,
        reference,
        sourceRole: 'patient',
        sourceUserId: patientId,
        sendPush: true,
      });

      console.info('payuWebhook pago aprobado', {patientId, treatmentId, reference, appliedMonto});
    } else if (state === 6 || state === 7) {
      await sessionRef.set(
        {
          estado: normalizedState,
          payuOrderId,
          payuTransactionId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      await notifyAdminPaymentEvent(db, {
        notificationId: `admin_${normalizedState}_${reference}`,
        patientId,
        patientName: account.patientName,
        paymentId: treatmentId,
        treatmentId,
        transactionId: payuTransactionId,
        type: state === 6 ? 'payment_failed' : 'payment_pending_validation',
        title: state === 6 ? 'Pago rechazado' : 'Pago pendiente de validación',
        body:
          state === 6
            ? `El pago de ${account.patientName} para ${account.treatmentName} por ${formatCop(montoSesion)} fue rechazado o falló.`
            : `Hay un pago de ${account.patientName} para ${account.treatmentName} pendiente por validar.`,
        amount: montoSesion,
        reference,
        sourceRole: 'system',
        sendPush: true,
      });

      console.info('payuWebhook estado no aprobado', {patientId, treatmentId, reference, state});
    } else {
      await sessionRef.set(
        {
          estado: normalizedState,
          payuOrderId,
          payuTransactionId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      console.info('payuWebhook estado no manejado explícitamente', {patientId, treatmentId, reference, statePol});
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error en payuWebhook', error);
    res.status(200).send('OK');
  }
});
