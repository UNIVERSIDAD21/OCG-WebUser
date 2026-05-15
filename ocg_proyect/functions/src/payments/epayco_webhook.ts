import * as crypto from 'crypto';
import {onRequest} from 'firebase-functions/v2/https';

import * as admin from 'firebase-admin';
import {resolveEpaycoConfig} from './epayco_config';
import {processEpaycoWebhook} from './epayco_webhook_core';

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

function normalizeNumber(value: unknown): number {
  return typeof value === 'number' ? value : Number(value ?? 0);
}

export const epaycoWebhook = onRequest({region: 'us-central1', cors: false}, async (req, res) => {
  try {
    const body = req.body ?? {};
    const epayco = resolveEpaycoConfig();

    // Epayco webhook sends: x_ref_payco, x_signature, x_estado, x_valor, x_currency, x_customer_id
    const reference = normalizeString(body.x_ref_payco || body.ref_payco || body.x_reference_code || '');
    const providedSign = normalizeString(body.x_signature || '').toLowerCase();
    const estado = normalizeString(body.x_estado || body.estado || '0');
    const statePol = estado === '3' ? 3 : estado === '4' ? 4 : estado === '1' ? 1 : Number(body.x_estado || 0);

    const payload = {
      reference,
      customerId: normalizeString(body.x_customer_id || body.customer_id || ''),
      value: normalizeNumber(body.x_valor || body.value || body.amount || 0),
      currency: normalizeString(body.x_currency || body.currency || 'COP'),
      estado,
      statePol,
      stateLabel: estado,
      sign: providedSign,
      epaycoOrderId: normalizeString(body.x_id_factura || body.x_order_id || body.order_id || ''),
      epaycoTransactionId: normalizeString(body.x_transaction_id || body.transaction_id || ''),
    };

    // Verify signature: SHA256 should match what Epayco sends
    // Epayco signature = SHA256(privateKey + customerId + referenceCode + amount)
    if (payload.reference && payload.value > 0 && payload.customerId) {
      const expectedSign = crypto
        .createHash('sha256')
        .update(`${epayco.privateKey}${payload.customerId}${payload.reference}${payload.value.toFixed(2)}`)
        .digest('hex')
        .toLowerCase();

      if (expectedSign !== payload.sign) {
        console.error('epaycoWebhook firma inválida', {
          reference: payload.reference,
          provided: payload.sign,
          expected: expectedSign,
        });
        res.status(401).send('Firma inválida');
        return;
      }
    }

    const result = await processEpaycoWebhook({
      db: admin.firestore(),
      epayco,
      payload,
    });

    console.info('epaycoWebhook result', {
      reference: payload.reference,
      action: result.action,
      sessionState: result.sessionState,
      transactionId: result.transactionId,
    });

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error en epaycoWebhook', error);
    res.status(200).send('OK');
  }
});
