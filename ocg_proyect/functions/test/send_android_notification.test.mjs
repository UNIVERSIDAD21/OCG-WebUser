import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildPayload,
  shouldSendEmailForCallable,
} from '../lib/notifications/send_android_notification.js';

test('callable de pago manual queda app-only porque el trigger de transacciones envia email', () => {
  const request = {
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago registrado',
    body: 'Se registro un pago.',
    type: 'payment',
    entityType: 'pago',
    entityId: 'p1',
    data: {
      monto: 100000,
      metodo: 'efectivo',
    },
  };

  const payload = buildPayload(request);

  assert.equal(payload.targetRoute, '/patient/payments');
  assert.equal(shouldSendEmailForCallable(payload, request), false);
});

test('callable respeta sendEmail=false explicitamente', () => {
  const request = {
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago registrado',
    body: 'Se registro un pago.',
    type: 'payment_received',
    entityType: 'payment',
    sendEmail: false,
  };

  const payload = buildPayload(request);

  assert.equal(payload.targetRoute, '/patient/payments');
  assert.equal(shouldSendEmailForCallable(payload, request), false);
});

test('callable ignora sendEmail=true para pagos porque los cubre el trigger transaccional', () => {
  const request = {
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago registrado',
    body: 'Se registro un pago.',
    type: 'payment_received',
    entityType: 'payment',
    sendEmail: true,
  };

  const payload = buildPayload(request);

  assert.equal(payload.targetRoute, '/patient/payments');
  assert.equal(shouldSendEmailForCallable(payload, request), false);
});
