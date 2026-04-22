import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import {onRequest} from 'firebase-functions/v2/https';

import {formatCop, notifyPatientPaymentEvent} from '../notifications/domain_notifications';

const SANDBOX_API_KEY = '4Vj8eK4rloUd272L48hsrarnUA';

export const payuWebhook = onRequest({region: 'us-central1', cors: false}, async (req, res) => {
  try {
    const body = req.body ?? {};

    const reference = String(body.reference_sale ?? '').trim();
    const merchantId = String(body.merchant_id ?? '').trim();
    const value = Number(body.value ?? 0);
    const currency = String(body.currency ?? 'COP').trim();
    const statePol = String(body.state_pol ?? '').trim();
    const sign = String(body.sign ?? '').trim().toLowerCase();

    const signRaw = [
      SANDBOX_API_KEY,
      merchantId,
      reference,
      value.toFixed(1),
      currency,
      statePol,
    ].join('~');

    const expectedSign = crypto.createHash('md5').update(signRaw).digest('hex').toLowerCase();

    if (expectedSign !== sign) {
      console.error('payuWebhook firma inválida', {
        reference,
        provided: sign,
        expected: expectedSign,
      });
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

    const session = sessionSnap.data() as {patientId?: string; monto?: number} | undefined;
    const patientId = session?.patientId ?? '';
    const monto = Number(session?.monto ?? 0);
    const state = Number(statePol);

    if (!patientId || !Number.isFinite(monto) || monto <= 0) {
      console.error('payuWebhook sesión inválida', {reference, patientId, monto});
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

    if (state === 4) {
      const paymentRef = db.collection('payments').doc(patientId);
      const paymentSnap = await paymentRef.get();
      if (!paymentSnap.exists) {
        console.error('payuWebhook payments no existe', {patientId, reference});
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

      const payment = paymentSnap.data() ?? {};
      const saldoActual = Number(payment.saldoPendiente ?? 0);
      const montoPagadoActual = Number(payment.montoPagado ?? 0);
      const fechaProximoPagoTs = payment.fechaProximoPago as admin.firestore.Timestamp | null;
      const fechaProximoPago = fechaProximoPagoTs ? fechaProximoPagoTs.toDate() : null;

      const appliedMonto = Math.min(monto, Math.max(saldoActual, 0));
      const nuevoSaldo = Math.max(0, saldoActual - appliedMonto);
      const nuevoPagado = montoPagadoActual + appliedMonto;

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

      const txRef = db.collection(`payments/${patientId}/transactions`).doc();
      const patientRef = db.collection('patients').doc(patientId);
      const batch = db.batch();

      batch.set(txRef, {
        id: txRef.id,
        monto: appliedMonto,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        metodo: 'payu',
        referencia: reference,
        registradoPor: 'payu_webhook',
        notas: 'Pago procesado por PayU Colombia',
        reciboUrl: null,
        payuOrderId: String(body.order_id ?? ''),
        payuTransactionId: String(body.transaction_id ?? ''),
      });

      batch.update(paymentRef, {
        montoPagado: nuevoPagado,
        saldoPendiente: nuevoSaldo,
        estado: nuevoEstado,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      batch.update(patientRef, {
        saldoPendiente: nuevoSaldo,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      batch.set(
        sessionRef,
        {
          estado: 'aprobado',
          payuOrderId: String(body.order_id ?? ''),
          payuTransactionId: String(body.transaction_id ?? ''),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      await batch.commit();

      await notifyPatientPaymentEvent(db, {
        notificationId: `payment_received_${reference}`,
        patientId,
        paymentId: paymentRef.id,
        treatmentId: String(payment.treatmentId ?? '').trim(),
        type: 'payment_received',
        title: 'Pago recibido con éxito',
        body: `Recibimos tu pago por ${formatCop(appliedMonto)}. Tu saldo pendiente ahora es ${formatCop(nuevoSaldo)}.`,
        amount: appliedMonto,
        dueDate: fechaProximoPago ?? undefined,
        reference,
      });

      console.info('payuWebhook pago aprobado', {patientId, reference, appliedMonto});
    } else if (state === 6) {
      await sessionRef.set(
        {
          estado: 'rechazado',
          payuOrderId: String(body.order_id ?? ''),
          payuTransactionId: String(body.transaction_id ?? ''),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      console.info('payuWebhook pago rechazado', {patientId, reference});
    } else if (state === 7) {
      await sessionRef.set(
        {
          estado: 'pendiente_confirmacion',
          payuOrderId: String(body.order_id ?? ''),
          payuTransactionId: String(body.transaction_id ?? ''),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      console.info('payuWebhook pago pendiente', {patientId, reference});
    } else {
      await sessionRef.set(
        {
          estado: `state_${statePol}`,
          payuOrderId: String(body.order_id ?? ''),
          payuTransactionId: String(body.transaction_id ?? ''),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      console.info('payuWebhook estado no manejado explícitamente', {patientId, reference, statePol});
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error en payuWebhook', error);
    res.status(200).send('OK');
  }
});
