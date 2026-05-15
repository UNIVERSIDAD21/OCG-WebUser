import test from 'node:test';
import assert from 'node:assert/strict';

import {renderEmailTemplate} from '../lib/notifications/email_templates.js';

function payload(type, overrides = {}) {
  return {
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Titulo',
    body: 'Mensaje principal',
    type,
    source: 'test',
    ...overrides,
  };
}

test('renderiza template de pago recibido', () => {
  const rendered = renderEmailTemplate(payload('payment_received'), {
    appLink: 'https://app.example.com/patient/payments',
  });

  assert.equal(rendered.subject, 'OCG Clinica - Pago recibido');
  assert.match(rendered.html, /Mensaje principal/);
  assert.match(rendered.html, /Ver pagos/);
  assert.match(rendered.text, /https:\/\/app\.example\.com\/patient\/payments/);
});

test('renderiza template de pago legacy desde callable manual', () => {
  const rendered = renderEmailTemplate(payload('payment'), {
    appLink: 'https://app.example.com/patient/payments',
  });

  assert.equal(rendered.subject, 'OCG Clinica - Pago recibido');
  assert.match(rendered.html, /Ver pagos/);
});

test('renderiza template de pago proximo a vencer', () => {
  const rendered = renderEmailTemplate(payload('payment_due_soon'), {
    appLink: 'https://app.example.com/patient/payments',
  });

  assert.equal(rendered.subject, 'OCG Clinica - Pago proximo a vencer');
  assert.match(rendered.html, /Ver pagos/);
  assert.match(rendered.text, /https:\/\/app\.example\.com\/patient\/payments/);
});

test('renderiza template de avance de tratamiento', () => {
  const rendered = renderEmailTemplate(payload('treatment_stage_updated'), {
    appLink: 'https://app.example.com/patient',
  });

  assert.equal(rendered.subject, 'OCG Clinica - Tu tratamiento avanzo');
  assert.match(rendered.html, /Ver tratamiento/);
});

test('renderiza template de recordatorio de cita', () => {
  const rendered = renderEmailTemplate(payload('appointment_reminder'), {
    appLink: 'https://app.example.com/patient/appointments',
  });

  assert.equal(rendered.subject, 'OCG Clinica - Recordatorio de cita');
  assert.match(rendered.html, /Ver citas/);
});

test('escapa html del payload', () => {
  const rendered = renderEmailTemplate(payload('generic', {
    title: '<script>alert(1)</script>',
    body: 'Hola <b>paciente</b>',
  }));

  assert.match(rendered.html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.match(rendered.html, /Hola &lt;b&gt;paciente&lt;\/b&gt;/);
});

