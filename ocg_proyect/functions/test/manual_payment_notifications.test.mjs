import test from 'node:test';
import assert from 'node:assert/strict';

import {
  handlePaymentTransactionCreate,
} from '../lib/payments/on_payment_transaction_create.js';

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
      out[key] = typeof raw === 'function' ? '[FieldValue]' : materialize(raw);
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

function seed() {
  return {
    'patients/p1': {id: 'p1', nombre: 'Paciente Uno', email: 'patient@example.com'},
    'patients/p1/treatments/t1': {
      id: 't1',
      visibleName: 'Ortodoncia',
      isPrimary: true,
    },
    'payments/p1/treatments/t1': {
      id: 't1',
      patientId: 'p1',
      treatmentId: 't1',
      totalTratamiento: 1000000,
      montoPagado: 200000,
      saldoPendiente: 800000,
    },
  };
}

test('transaccion manual de pago notifica al paciente por email', async () => {
  enableMockEmail();
  const db = new MockFirestore(seed());

  const result = await handlePaymentTransactionCreate(
    db,
    {patientId: 'p1', treatmentId: 't1', transactionId: 'tx1'},
    {
      id: 'tx1',
      patientId: 'p1',
      treatmentId: 't1',
      monto: 200000,
      metodo: 'efectivo',
      registradoPor: 'admin1',
      referencia: 'REC-001',
    },
  );

  const persisted = db.store.get('notifications/manual_payment_received_tx1');
  assert.equal(result, 'notified');
  assert.equal(persisted.recipientRole, 'patient');
  assert.equal(persisted.type, 'payment_received');
  assert.equal(persisted.targetRoute, '/patient/payments');
  assert.equal(persisted.entityType, 'payment');
  assert.equal(persisted.paymentId, 't1');
  assert.equal(persisted.payload.amount, '200000');
  assert.equal(persisted.payload.reference, 'REC-001');
  assert.equal(persisted.delivery.status, 'skipped_no_active_tokens');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailTo, 'patient@example.com');
  assert.deepEqual(persisted.channels, ['app', 'email']);
});

test('transaccion manual notifica aunque falte la cuenta financiera del tratamiento', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', nombre: 'Paciente Uno', email: 'patient@example.com'},
    'patients/p1/treatments/t1': {
      id: 't1',
      visibleName: 'Ortodoncia',
      isPrimary: true,
    },
  });

  const result = await handlePaymentTransactionCreate(
    db,
    {patientId: 'p1', treatmentId: 't1', transactionId: 'tx_no_account'},
    {
      id: 'tx_no_account',
      patientId: 'p1',
      treatmentId: 't1',
      monto: 150000,
      metodo: 'efectivo',
      registradoPor: 'admin1',
    },
  );

  const persisted = db.store.get('notifications/manual_payment_received_tx_no_account');
  assert.equal(result, 'notified');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailTo, 'patient@example.com');
  assert.equal(persisted.payload.amount, '150000');
  assert.match(persisted.body, /Ortodoncia/);
});

test('transaccion de ePayco se omite para no duplicar el webhook', async () => {
  enableMockEmail();
  const db = new MockFirestore(seed());

  const result = await handlePaymentTransactionCreate(
    db,
    {patientId: 'p1', treatmentId: 't1', transactionId: 'epayco_REF1'},
    {
      id: 'epayco_REF1',
      patientId: 'p1',
      treatmentId: 't1',
      monto: 200000,
      metodo: 'epayco',
      registradoPor: 'epayco_webhook',
      epaycoTransactionId: 'EPAYCO-TX',
    },
  );

  assert.equal(result, 'skipped');
  assert.equal(db.store.has('notifications/manual_payment_received_epayco_REF1'), false);
});

test('transaccion migrada se omite para no enviar correos historicos', async () => {
  enableMockEmail();
  const db = new MockFirestore(seed());

  const result = await handlePaymentTransactionCreate(
    db,
    {patientId: 'p1', treatmentId: 't1', transactionId: 'legacy1'},
    {
      id: 'legacy1',
      patientId: 'p1',
      treatmentId: 't1',
      monto: 200000,
      metodo: 'efectivo',
      registradoPor: 'admin1',
      legacySource: true,
    },
  );

  assert.equal(result, 'skipped');
  assert.equal(db.store.has('notifications/manual_payment_received_legacy1'), false);
});
