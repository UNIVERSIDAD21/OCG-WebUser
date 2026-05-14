import test from 'node:test';
import assert from 'node:assert/strict';

import {
  notifyAdminPaymentEvent,
  notifyPatientPaymentEvent,
} from '../lib/notifications/domain_notifications.js';

class MockDocSnapshot {
  constructor(path, data) {
    this.ref = {path};
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
    const previous = this.db.store.get(this.path);
    this.db.store.set(this.path, options.merge && previous ? deepMerge(previous, material) : material);
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
      if (typeof raw === 'function') {
        out[key] = '[FieldValue]';
      } else {
        out[key] = materialize(raw);
      }
    }
    return out;
  }
  return value;
}

function deepMerge(base, update) {
  const output = {...base};
  for (const [key, value] of Object.entries(update)) {
    if (
      value &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      base[key] &&
      typeof base[key] === 'object' &&
      !Array.isArray(base[key])
    ) {
      output[key] = deepMerge(base[key], value);
    } else {
      output[key] = value;
    }
  }
  return output;
}

const previousEnv = {...process.env};

test.afterEach(() => {
  process.env = {...previousEnv};
});

function enableMockEmail() {
  process.env.EMAIL_ENABLED = 'true';
  process.env.EMAIL_PROVIDER = 'mock';
  process.env.EMAIL_FROM = 'OCG Clinica <sender@example.com>';
  process.env.EMAIL_REPLY_TO = 'reply@example.com';
  process.env.EMAIL_APP_BASE_URL = 'https://app.example.com';
}

test('notifyPatientPaymentEvent entrega email y conserva historial push skipped si no hay token', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
  });

  await notifyPatientPaymentEvent(db, {
    notificationId: 'payment_received_ref1',
    patientId: 'p1',
    paymentId: 't1',
    treatmentId: 't1',
    type: 'payment_received',
    title: 'Pago recibido con exito',
    body: 'Recibimos tu pago.',
    amount: 100000,
    reference: 'ref1',
  });

  const persisted = db.store.get('notifications/payment_received_ref1');
  assert.equal(persisted.recipientRole, 'patient');
  assert.equal(persisted.type, 'payment_received');
  assert.equal(persisted.delivery.status, 'skipped_no_active_tokens');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailTo, 'patient@example.com');
  assert.deepEqual(persisted.channels, ['app', 'email']);
});

test('notifyAdminPaymentEvent con sendPush false envia email sin intentar push', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'admins/a1': {id: 'a1', email: 'admin@example.com'},
  });

  await notifyAdminPaymentEvent(db, {
    notificationId: 'admin_payment_due_soon_ref1',
    patientId: 'p1',
    patientName: 'Paciente Uno',
    paymentId: 't1',
    treatmentId: 't1',
    type: 'payment_due_soon',
    title: 'Pago proximo a vencer',
    body: 'Paciente Uno tiene un pago proximo.',
    amount: 100000,
    sourceRole: 'system',
    sendPush: false,
  });

  const persisted = db.store.get('notifications/admin_payment_due_soon_ref1_a1');
  assert.equal(persisted.recipientRole, 'admin');
  assert.equal(persisted.type, 'payment_due_soon');
  assert.equal(persisted.delivery.status, 'internal_only');
  assert.equal(persisted.pushSent, false);
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailTo, 'admin@example.com');
  assert.deepEqual(persisted.channels, ['email']);
});

