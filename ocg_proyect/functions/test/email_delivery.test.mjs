import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildEmailAppLink,
  isEmailRuntimeReady,
  resolveEmailRuntimeConfig,
} from '../lib/notifications/email_config.js';
import {
  buildPendingEmailDeliveryResult,
  buildSkippedEmailDeliveryResult,
  isValidEmail,
  maskEmail,
  resolveEmailRecipient,
  sendEmailNotification,
} from '../lib/notifications/email_delivery.js';

class MockDocSnapshot {
  constructor(path, data) {
    this.path = path;
    this.id = path.split('/').pop();
    this._data = data;
    this.exists = data !== undefined;
  }

  data() {
    return this._data;
  }
}

class MockDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split('/').pop();
  }

  async get() {
    return new MockDocSnapshot(this.path, this.db.store.get(this.path));
  }
}

class MockCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new MockDocRef(this.db, `${this.path}/${id}`);
  }
}

class MockFirestore {
  constructor(seed = {}) {
    this.store = new Map(Object.entries(seed));
  }

  collection(path) {
    return new MockCollectionRef(this, path);
  }
}

test('valida sintaxis basica de email', () => {
  assert.equal(isValidEmail('PACIENTE@EXAMPLE.COM'), true);
  assert.equal(isValidEmail('bad-email'), false);
  assert.equal(isValidEmail('a@@example.com'), false);
  assert.equal(isValidEmail('a..b@example.com'), false);
});

test('resuelve email principal de paciente', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'Paciente@Example.com'},
  });

  const result = await resolveEmailRecipient(db, 'patient', 'p1');
  assert.equal(result.ok, true);
  assert.equal(result.recipient.email, 'paciente@example.com');
  assert.equal(result.recipient.sourceField, 'email');
});

test('resuelve fallback correo para paciente', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: '', correo: 'fallback@example.com'},
  });

  const result = await resolveEmailRecipient(db, 'patient', 'p1');
  assert.equal(result.ok, true);
  assert.equal(result.recipient.email, 'fallback@example.com');
  assert.equal(result.recipient.sourceField, 'correo');
});

test('resuelve fallback patientEmail para paciente', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'bad-email', correo: '', patientEmail: 'payu@example.com'},
  });

  const result = await resolveEmailRecipient(db, 'patient', 'p1');
  assert.equal(result.ok, true);
  assert.equal(result.recipient.email, 'payu@example.com');
  assert.equal(result.recipient.sourceField, 'patientEmail');
});

test('resuelve email de admin', async () => {
  const db = new MockFirestore({
    'admins/a1': {email: 'admin@example.com'},
  });

  const result = await resolveEmailRecipient(db, 'admin', 'a1');
  assert.equal(result.ok, true);
  assert.equal(result.recipient.email, 'admin@example.com');
  assert.equal(result.recipient.sourceField, 'email');
});

test('omite si el destinatario no tiene email valido', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'bad-email'},
  });

  const result = await resolveEmailRecipient(db, 'patient', 'p1');
  assert.equal(result.ok, false);
  assert.equal(result.status, 'skipped_no_email');
  assert.equal(result.reason, 'no_valid_email_field');
});

test('lee configuracion runtime de email', () => {
  const config = resolveEmailRuntimeConfig({
    EMAIL_ENABLED: 'true',
    EMAIL_PROVIDER: 'brevo',
    BREVO_API_KEY: 'test-key',
    EMAIL_FROM: 'OCG Clinica <no-reply@example.com>',
    EMAIL_REPLY_TO: 'hola@example.com',
    EMAIL_APP_BASE_URL: 'https://app.example.com/',
  });

  assert.equal(config.enabled, true);
  assert.equal(config.provider, 'brevo');
  assert.equal(config.brevoApiKey, 'test-key');
  assert.equal(config.from, 'OCG Clinica <no-reply@example.com>');
  assert.equal(config.replyTo, 'hola@example.com');
  assert.equal(isEmailRuntimeReady(config), true);
});

test('configuracion Brevo no esta lista si falta api key', () => {
  const config = resolveEmailRuntimeConfig({
    EMAIL_ENABLED: 'true',
    EMAIL_PROVIDER: 'brevo',
    EMAIL_FROM: 'OCG Clinica <no-reply@example.com>',
  });

  assert.equal(isEmailRuntimeReady(config), false);
});

test('construye link seguro hacia portal', () => {
  const config = {appBaseUrl: 'https://app.example.com/'};
  assert.equal(buildEmailAppLink(config, '/patient/payments'), 'https://app.example.com/patient/payments');
  assert.equal(buildEmailAppLink(config, 'https://evil.example.com'), 'https://app.example.com');
});

test('construye snapshots de delivery email', () => {
  const skipped = buildSkippedEmailDeliveryResult({
    status: 'skipped_disabled',
    code: 'EMAIL_DISABLED',
    message: 'Email disabled.',
  });
  assert.equal(skipped.status, 'skipped_disabled');
  assert.equal(skipped.attempted, 0);
  assert.equal(skipped.error.code, 'EMAIL_DISABLED');

  const pending = buildPendingEmailDeliveryResult({
    provider: 'brevo',
    to: 'patient@example.com',
  });
  assert.equal(pending.status, 'pending');
  assert.equal(pending.provider, 'brevo');
  assert.equal(pending.to, 'patient@example.com');
});

test('mock envia sin llamar proveedor real', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com'},
  });
  const result = await sendEmailNotification(db, {
    notificationId: 'n1',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    targetRoute: '/patient/payments',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'true',
      EMAIL_PROVIDER: 'mock',
      EMAIL_FROM: 'OCG Clinica <no-reply@example.com>',
      EMAIL_APP_BASE_URL: 'https://app.example.com',
    },
  });

  assert.equal(result.status, 'sent');
  assert.equal(result.provider, 'mock');
  assert.equal(result.providerMessageId, 'mock_n1');
});

test('Brevo envia usando /v3/smtp/email', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com'},
  });
  const calls = [];
  const result = await sendEmailNotification(db, {
    notificationId: 'n-brevo',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    targetRoute: '/patient/payments',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'true',
      EMAIL_PROVIDER: 'brevo',
      BREVO_API_KEY: 'brevo-test-key',
      EMAIL_FROM: 'OCG Clinica <sender@example.com>',
      EMAIL_REPLY_TO: 'reply@example.com',
      EMAIL_APP_BASE_URL: 'https://app.example.com',
    },
    fetchImpl: async (url, init) => {
      calls.push({url, init});
      return {
        ok: true,
        status: 201,
        json: async () => ({messageId: 'brevo-message-id'}),
      };
    },
  });

  assert.equal(result.status, 'sent');
  assert.equal(result.provider, 'brevo');
  assert.equal(result.providerMessageId, 'brevo-message-id');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(calls[0].init.headers['api-key'], 'brevo-test-key');
  const body = JSON.parse(calls[0].init.body);
  assert.deepEqual(body.to, [{email: 'patient@example.com'}]);
  assert.equal(body.sender.email, 'sender@example.com');
  assert.equal(body.sender.name, 'OCG Clinica');
  assert.equal(body.replyTo.email, 'reply@example.com');
  assert.equal(body.subject, 'OCG Clinica - Pago recibido');
  assert.match(body.htmlContent, /https:\/\/app\.example\.com\/patient\/payments/);
});

test('Brevo registra error del proveedor', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com'},
  });
  const result = await sendEmailNotification(db, {
    notificationId: 'n-error',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'true',
      EMAIL_PROVIDER: 'brevo',
      BREVO_API_KEY: 'brevo-test-key',
      EMAIL_FROM: 'sender@example.com',
    },
    fetchImpl: async () => ({
      ok: false,
      status: 401,
      json: async () => ({code: 'unauthorized', message: 'Invalid API key'}),
    }),
  });

  assert.equal(result.status, 'failed');
  assert.equal(result.provider, 'brevo');
  assert.equal(result.error.code, 'unauthorized');
  assert.equal(result.error.message, 'Invalid API key');
});

test('Brevo no intenta enviar si falta secret API key', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com'},
  });
  const result = await sendEmailNotification(db, {
    notificationId: 'n-missing-key',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'true',
      EMAIL_PROVIDER: 'brevo',
      EMAIL_FROM: 'sender@example.com',
    },
  });

  assert.equal(result.status, 'skipped_disabled');
  assert.equal(result.error.code, 'BREVO_API_KEY_MISSING');
});

// ── Bloque 09: nuevos casos ────────────────────────────────────────────────

test('omite si EMAIL_ENABLED=false global', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com'},
  });
  const result = await sendEmailNotification(db, {
    notificationId: 'n-disabled-global',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'false',
    },
  });

  assert.equal(result.status, 'skipped_disabled');
  assert.equal(result.error.code, 'EMAIL_DISABLED');
});

test('omite si paciente desactivo emailEnabled en Firestore', async () => {
  const db = new MockFirestore({
    'patients/p1': {email: 'patient@example.com', emailEnabled: false},
  });
  const result = await sendEmailNotification(db, {
    notificationId: 'n-user-optout',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    source: 'test',
  }, {
    env: {
      EMAIL_ENABLED: 'true',
      EMAIL_PROVIDER: 'mock',
      EMAIL_FROM: 'OCG Clinica <no-reply@example.com>',
    },
  });

  assert.equal(result.status, 'skipped_user_opt_out');
  assert.equal(result.error.code, 'user_disabled_email');
});

test('maskEmail no expone email completo en logs', () => {
  assert.equal(maskEmail('juanperez@gmail.com'), 'ju***@gmail.com');
  assert.equal(maskEmail('a@b.com'), 'a***@b.com');
  assert.equal(maskEmail('ab@c.com'), 'ab***@c.com');
});
