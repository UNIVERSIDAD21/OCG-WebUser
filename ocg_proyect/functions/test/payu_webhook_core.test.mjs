import test from 'node:test';
import assert from 'node:assert/strict';

import {isAuthorizedPayuCaller, processPayuWebhook} from '../lib/payments/payu_webhook_core.js';

class MockDocSnapshot {
  constructor(path, data) {
    this.ref = {path};
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
  collection(name) {
    return new MockCollectionRef(this.db, `${this.path}/${name}`);
  }
  async set(data, options = {}) {
    const previous = this.db.store.get(this.path);
    if (options.merge && previous) {
      this.db.store.set(this.path, deepMerge(previous, materialize(data)));
    } else {
      this.db.store.set(this.path, materialize(data));
    }
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

class MockTransaction {
  constructor(db) {
    this.db = db;
    this.writes = [];
  }
  async get(ref) {
    return ref.get();
  }
  set(ref, data, options = {}) {
    this.writes.push({kind: 'set', ref, data, options});
  }
  create(ref, data) {
    this.writes.push({kind: 'create', ref, data});
  }
  commit() {
    for (const write of this.writes) {
      const previous = this.db.store.get(write.ref.path);
      if (write.kind === 'create') {
        if (previous !== undefined) {
          throw new Error(`Document already exists: ${write.ref.path}`);
        }
        this.db.store.set(write.ref.path, materialize(write.data));
        continue;
      }
      if (write.options.merge && previous) {
        this.db.store.set(write.ref.path, deepMerge(previous, materialize(write.data)));
      } else {
        this.db.store.set(write.ref.path, materialize(write.data));
      }
    }
  }
}

class MockFirestore {
  constructor(seed = {}) {
    this.store = new Map(Object.entries(seed));
  }
  collection(path) {
    return new MockCollectionRef(this, path);
  }
  async runTransaction(handler) {
    const tx = new MockTransaction(this);
    const result = await handler(tx);
    tx.commit();
    return result;
  }
}

function materialize(value) {
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [key, inner] of Object.entries(value)) {
      if (typeof inner === 'function') {
        out[key] = '[FieldValue]';
      } else {
        out[key] = materialize(inner);
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

function payuConfig() {
  return {
    apiKey: '4Vj8eK4rloUd272L48hsrarnUA',
    merchantId: '508029',
    accountId: '512321',
    checkoutUrl: 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/',
    test: '1',
    environment: 'sandbox',
  };
}

function seedBase() {
  return {
    'patients/p1': {id: 'p1', nombre: 'Paciente Uno', email: 'p1@test.com'},
    'patients/p1/treatments/tA': {id: 'tA', nombre: 'Tratamiento A', isPrimary: true, saldoPendiente: 1000000},
    'patients/p1/treatments/tB': {id: 'tB', nombre: 'Tratamiento B', isPrimary: false, saldoPendiente: 800000},
    'payments/p1/treatments/tA': {
      id: 'tA', patientId: 'p1', treatmentId: 'tA', totalTratamiento: 1000000, montoPagado: 0,
      saldoPendiente: 1000000, estado: 'pendiente', createdAt: 'created-A', updatedAt: 'updated-A',
    },
    'payments/p1/treatments/tB': {
      id: 'tB', patientId: 'p1', treatmentId: 'tB', totalTratamiento: 800000, montoPagado: 0,
      saldoPendiente: 800000, estado: 'pendiente', createdAt: 'created-B', updatedAt: 'updated-B',
    },
  };
}

function session(reference, treatmentId, monto, estado = 'pendiente') {
  return {
    [`payu_sessions/${reference}`]: {
      referencia: reference,
      patientId: 'p1',
      treatmentId,
      monto,
      estado,
      createdAt: 'session-created',
      updatedAt: 'session-updated',
    },
  };
}

function payload(reference, overrides = {}) {
  return {
    reference,
    merchantId: '508029',
    value: 300000,
    currency: 'COP',
    statePol: 4,
    stateLabel: '4',
    sign: 'valid',
    payuOrderId: 'ORDER-1',
    payuTransactionId: 'TX-1',
    ...overrides,
  };
}

const noOpNotifyPatient = async () => {};
const noOpNotifyAdmin = async () => {};

test('autorización: paciente A no puede iniciar PayU para paciente B', async () => {
  const db = new MockFirestore({'admins/admin1': {active: true}});
  const result = await isAuthorizedPayuCaller({
    db,
    auth: {uid: 'patient-A', token: {}},
    patientId: 'patient-B',
  });
  assert.deepEqual(result, {allowed: false});
});

test('autorización: paciente correcto puede iniciar su tratamiento', async () => {
  const db = new MockFirestore();
  const result = await isAuthorizedPayuCaller({
    db,
    auth: {uid: 'p1', token: {}},
    patientId: 'p1',
  });
  assert.deepEqual(result, {allowed: true, role: 'patient'});
});

test('autorización: admin puede iniciar PayU para paciente', async () => {
  const db = new MockFirestore({'admins/admin1': {active: true}});
  const result = await isAuthorizedPayuCaller({
    db,
    auth: {uid: 'admin1', token: {}},
    patientId: 'p1',
  });
  assert.deepEqual(result, {allowed: true, role: 'admin'});
});

test('webhook aprobado aplica pago al tratamiento A y no toca B', async () => {
  const reference = 'REF-A';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'approved_applied');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 700000);
  assert.equal(db.store.get('payments/p1/treatments/tB').saldoPendiente, 800000);
  assert.equal(db.store.get('payments/p1/treatments/tA/transactions/payu_REF-A').monto, 300000);
});

test('webhook aprobado duplicado no duplica transacción ni saldo', async () => {
  const reference = 'REF-DUP';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});
  const params = {
    db,
    payu: payuConfig(),
    payload: payload(reference),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  };

  await processPayuWebhook(params);
  const second = await processPayuWebhook(params);

  assert.equal(second.action, 'ignored_terminal_approved');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 700000);
  assert.equal(db.store.get('payments/p1/treatments/tA/transactions/payu_REF-DUP').monto, 300000);
});

test('webhook rechazado no modifica saldo', async () => {
  const reference = 'REF-REJ';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference, {statePol: 6, stateLabel: '6'}),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'non_approved_recorded');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 1000000);
  assert.equal(db.store.get('payu_sessions/REF-REJ').estado, 'rechazado');
  assert.equal(db.store.has('payments/p1/treatments/tA/transactions/payu_REF-REJ'), false);
});

test('webhook pendiente no modifica saldo y marca pendiente_confirmacion', async () => {
  const reference = 'REF-PEND';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference, {statePol: 7, stateLabel: '7'}),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'non_approved_recorded');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 1000000);
  assert.equal(db.store.get('payu_sessions/REF-PEND').estado, 'pendiente_confirmacion');
});

test('pendiente y luego aprobado aplica una sola vez', async () => {
  const reference = 'REF-PA';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});
  const base = {db, payu: payuConfig(), notifyPatientPayment: noOpNotifyPatient, notifyAdminPayment: noOpNotifyAdmin};

  await processPayuWebhook({...base, payload: payload(reference, {statePol: 7, stateLabel: '7'})});
  const result = await processPayuWebhook({...base, payload: payload(reference)});

  assert.equal(result.action, 'approved_applied');
  assert.equal(db.store.get(`payu_sessions/${reference}`).estado, 'aprobado');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 700000);
});

test('aprobado y luego rechazado conserva aprobado y no revierte', async () => {
  const reference = 'REF-FINAL';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});
  const base = {db, payu: payuConfig(), notifyPatientPayment: noOpNotifyPatient, notifyAdminPayment: noOpNotifyAdmin};

  await processPayuWebhook({...base, payload: payload(reference)});
  const result = await processPayuWebhook({...base, payload: payload(reference, {statePol: 6, stateLabel: '6'})});

  assert.equal(result.action, 'ignored_terminal_approved');
  assert.equal(db.store.get(`payu_sessions/${reference}`).estado, 'aprobado');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 700000);
});

test('monto PayU diferente al monto de sesión no aplica pago', async () => {
  const reference = 'REF-AMOUNT';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference, {value: 300001}),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'error_recorded');
  assert.equal(db.store.get('payments/p1/treatments/tA').saldoPendiente, 1000000);
  assert.equal(db.store.get(`payu_sessions/${reference}`).errorCode, 'amount_mismatch');
});

test('moneda diferente a COP no aplica pago', async () => {
  const reference = 'REF-USD';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference, {currency: 'USD'}),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'error_recorded');
  assert.equal(db.store.get(`payu_sessions/${reference}`).errorCode, 'currency_mismatch');
});

test('merchant incorrecto no aplica pago', async () => {
  const reference = 'REF-MERCHANT';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference, {merchantId: '999999'}),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'error_recorded');
  assert.equal(db.store.get(`payu_sessions/${reference}`).errorCode, 'merchant_mismatch');
});

test('sesión sin treatmentId no aplica pago', async () => {
  const reference = 'REF-NO-TX';
  const db = new MockFirestore({...seedBase(), ...session(reference, '', 300000)});

  const result = await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(result.action, 'error_recorded');
  assert.equal(db.store.get(`payu_sessions/${reference}`).errorCode, 'invalid_session');
});

test('createdAt de la cuenta se conserva después de webhook aprobado', async () => {
  const reference = 'REF-CREATED';
  const db = new MockFirestore({...seedBase(), ...session(reference, 'tA', 300000)});

  await processPayuWebhook({
    db,
    payu: payuConfig(),
    payload: payload(reference),
    notifyPatientPayment: noOpNotifyPatient,
    notifyAdminPayment: noOpNotifyAdmin,
  });

  assert.equal(db.store.get('payments/p1/treatments/tA').createdAt, 'created-A');
});
