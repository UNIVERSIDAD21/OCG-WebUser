import test from 'node:test';
import assert from 'node:assert/strict';

import {deliverNotification} from '../lib/notifications/notification_delivery_service.js';

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

  collection(name) {
    return new MockCollectionRef(this.db, `${this.path}/${name}`);
  }

  async get() {
    return new MockDocSnapshot(this.path, this.db.store.get(this.path));
  }

  async set(data, options = {}) {
    const material = materialize(data);
    const prev = this.db.store.get(this.path);
    this.db.store.set(this.path, options.merge && prev ? deepMerge(prev, material) : material);
  }
}

class MockQuerySnapshot {
  constructor(docs) {
    this.docs = docs;
    this.empty = docs.length === 0;
  }
}

class MockQuery {
  constructor(db, path, filters = []) {
    this.db = db;
    this.path = path;
    this.filters = filters;
  }

  where(field, op, value) {
    return new MockQuery(this.db, this.path, [...this.filters, {field, op, value}]);
  }

  async get() {
    const prefix = `${this.path}/`;
    const docs = [];
    for (const [path, data] of this.db.store.entries()) {
      if (!path.startsWith(prefix)) continue;
      const rest = path.slice(prefix.length);
      if (rest.includes('/')) continue;
      let match = true;
      for (const filter of this.filters) {
        if (filter.op === '==') match = data?.[filter.field] === filter.value;
        if (!match) break;
      }
      if (match) docs.push(new MockDocSnapshot(path, data));
    }
    return new MockQuerySnapshot(docs);
  }
}

class MockCollectionRef extends MockQuery {
  constructor(db, path) {
    super(db, path);
    this.path = path;
  }

  doc(id) {
    return new MockDocRef(this.db, `${this.path}/${id ?? this.db.nextId()}`);
  }
}

class MockFirestore {
  constructor(seed = {}) {
    this.store = new Map(Object.entries(seed));
    this.counter = 0;
  }

  collection(path) {
    return new MockCollectionRef(this, path);
  }

  nextId() {
    this.counter += 1;
    return `auto_${this.counter}`;
  }
}

function materialize(value) {
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [key, raw] of Object.entries(value)) {
      out[key] = typeof raw === 'function' ? '[FieldValue]' : materialize(raw);
    }
    return out;
  }
  return value;
}

function deepMerge(a, b) {
  const out = {...a};
  for (const [key, value] of Object.entries(b)) {
    if (
      value &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      a[key] &&
      typeof a[key] === 'object' &&
      !Array.isArray(a[key])
    ) {
      out[key] = deepMerge(a[key], value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

function basePayload(overrides = {}) {
  return {
    notificationId: 'n1',
    recipientId: 'p1',
    recipientRole: 'patient',
    title: 'Pago recibido',
    body: 'Recibimos tu pago.',
    type: 'payment_received',
    targetRoute: '/patient/payments',
    entityId: 'payment1',
    entityType: 'payment',
    data: {paymentId: 'payment1'},
    source: 'test',
    ...overrides,
  };
}

function emailEnv(provider = 'mock') {
  return {
    EMAIL_ENABLED: 'true',
    EMAIL_PROVIDER: provider,
    BREVO_API_KEY: provider === 'brevo' ? 'brevo-key' : '',
    EMAIL_FROM: 'OCG Clinica <sender@example.com>',
    EMAIL_REPLY_TO: 'reply@example.com',
    EMAIL_APP_BASE_URL: 'https://app.example.com',
  };
}

test('entrega push y email mock y persiste ambos resultados', async () => {
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
    'patients/p1/devices/d1': {token: 'token-1', platform: 'android', active: true},
  });

  const result = await deliverNotification(db, basePayload(), {
    messagingOverride: {send: async () => 'fcm-message-id'},
    emailOptions: {env: emailEnv('mock')},
  });

  assert.equal(result.notificationId, 'n1');
  assert.equal(result.delivery.status, 'sent');
  assert.equal(result.emailDelivery.status, 'sent');

  const persisted = db.store.get('notifications/n1');
  assert.equal(persisted.pushSent, true);
  assert.equal(persisted.delivery.status, 'sent');
  assert.equal(persisted.emailSent, true);
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailProviderMessageId, 'mock_n1');
  assert.deepEqual(persisted.channels, ['app', 'email']);
});

test('sin token push conserva email enviado', async () => {
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
  });

  const result = await deliverNotification(db, basePayload({notificationId: 'n2'}), {
    messagingOverride: {send: async () => 'never'},
    emailOptions: {env: emailEnv('mock')},
  });

  assert.equal(result.delivery.status, 'skipped_no_active_tokens');
  assert.equal(result.emailDelivery.status, 'sent');

  const persisted = db.store.get('notifications/n2');
  assert.equal(persisted.pushSent, false);
  assert.equal(persisted.emailStatus, 'sent');
});

test('push ok y email sin correo persisten estado skipped_no_email', async () => {
  const db = new MockFirestore({
    'patients/p1': {id: 'p1'},
    'patients/p1/devices/d1': {token: 'token-1', platform: 'ios', active: true},
  });

  const result = await deliverNotification(db, basePayload({notificationId: 'n3'}), {
    messagingOverride: {send: async () => 'fcm-message-id'},
    emailOptions: {env: emailEnv('mock')},
  });

  assert.equal(result.delivery.status, 'sent');
  assert.equal(result.emailDelivery.status, 'skipped_no_email');

  const persisted = db.store.get('notifications/n3');
  assert.equal(persisted.pushSent, true);
  assert.equal(persisted.emailStatus, 'skipped_no_email');
  assert.equal(persisted.emailError.code, 'no_valid_email_field');
});

test('Brevo falla y push ok persiste error de email', async () => {
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
    'patients/p1/devices/d1': {token: 'token-1', platform: 'android', active: true},
  });

  const result = await deliverNotification(db, basePayload({notificationId: 'n4'}), {
    messagingOverride: {send: async () => 'fcm-message-id'},
    emailOptions: {
      env: emailEnv('brevo'),
      fetchImpl: async () => ({
        ok: false,
        status: 401,
        json: async () => ({code: 'unauthorized', message: 'Invalid API key'}),
      }),
    },
  });

  assert.equal(result.delivery.status, 'sent');
  assert.equal(result.emailDelivery.status, 'failed');

  const persisted = db.store.get('notifications/n4');
  assert.equal(persisted.pushSent, true);
  assert.equal(persisted.emailStatus, 'failed');
  assert.equal(persisted.emailProvider, 'brevo');
  assert.equal(persisted.emailError.code, 'unauthorized');
});

test('canal app-only mantiene compatibilidad sin email', async () => {
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
    'patients/p1/devices/d1': {token: 'token-1', platform: 'android', active: true},
  });

  const result = await deliverNotification(db, basePayload({
    notificationId: 'n5',
    channels: {app: true, email: false},
  }), {
    messagingOverride: {send: async () => 'fcm-message-id'},
    emailOptions: {env: emailEnv('mock')},
  });

  assert.equal(result.delivery.status, 'sent');
  assert.equal(result.emailDelivery, undefined);

  const persisted = db.store.get('notifications/n5');
  assert.equal(persisted.pushSent, true);
  assert.equal(persisted.emailStatus, null);
  assert.deepEqual(persisted.channels, ['app']);
});

