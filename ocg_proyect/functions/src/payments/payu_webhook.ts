import * as crypto from 'crypto';
import {onRequest} from 'firebase-functions/v2/https';

import * as admin from 'firebase-admin';
import {resolvePayuConfig} from './payu_config';
import {processPayuWebhook} from './payu_webhook_core';

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

    const payload = {
      reference: normalizeString(body.reference_sale),
      merchantId: normalizeString(body.merchant_id),
      value: normalizeNumber(body.value),
      currency: normalizeString(body.currency || 'COP'),
      statePol: Number(body.state_pol ?? 0),
      stateLabel: normalizeString(body.state_pol),
      sign: normalizeString(body.sign).toLowerCase(),
      payuOrderId: normalizeString(body.order_id),
      payuTransactionId: normalizeString(body.transaction_id),
    };

    const signRaw = [
      payu.apiKey,
      payload.merchantId,
      payload.reference,
      payload.value.toFixed(1),
      payload.currency,
      String(payload.statePol),
    ].join('~');

    const expectedSign = crypto.createHash('md5').update(signRaw).digest('hex').toLowerCase();

    if (expectedSign !== payload.sign) {
      console.error('payuWebhook firma inválida', {
        reference: payload.reference,
        provided: payload.sign,
        expected: expectedSign,
      });
      res.status(401).send('Firma inválida');
      return;
    }

    const result = await processPayuWebhook({
      db: admin.firestore(),
      payu,
      payload,
    });

    console.info('payuWebhook result', {
      reference: payload.reference,
      action: result.action,
      sessionState: result.sessionState,
      transactionId: result.transactionId,
    });

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error en payuWebhook', error);
    res.status(200).send('OK');
  }
});
