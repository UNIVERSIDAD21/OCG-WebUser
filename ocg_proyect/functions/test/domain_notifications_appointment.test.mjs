import test from 'node:test';
import assert from 'node:assert/strict';

import {
  notifyAdminAppointmentEvent,
  notifyPatientAppointmentEvent,
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

test('notifyPatientAppointmentEvent entrega cita por app/email', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
  });

  await notifyPatientAppointmentEvent(db, {
    notificationId: 'appointment_a1_created',
    patientId: 'p1',
    appointmentId: 'a1',
    treatmentId: 't1',
    type: 'appointment_created',
    title: 'Nueva cita agendada',
    body: 'Tu cita fue agendada.',
    appointmentAt: new Date('2026-06-01T15:00:00.000Z'),
  });

  const persisted = db.store.get('notifications/appointment_a1_created');
  assert.equal(persisted.recipientRole, 'patient');
  assert.equal(persisted.type, 'appointment_created');
  assert.equal(persisted.targetRoute, '/patient/appointments');
  assert.equal(persisted.entityType, 'appointment');
  assert.equal(persisted.appointmentId, 'a1');
  assert.equal(persisted.delivery.status, 'skipped_no_active_tokens');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailTo, 'patient@example.com');
  assert.deepEqual(persisted.channels, ['app', 'email']);
  assert.equal(persisted.payload.appointmentId, 'a1');
  assert.equal(persisted.payload.treatmentId, 't1');
});

test('notifyAdminAppointmentEvent envia email a admins junto al canal app', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'admins/a1': {id: 'a1', email: 'admin@example.com'},
  });

  await notifyAdminAppointmentEvent(db, {
    notificationId: 'admin_appointment_a1_cancelled',
    patientId: 'p1',
    patientName: 'Paciente Uno',
    appointmentId: 'a1',
    treatmentId: 't1',
    type: 'appointment_cancelled',
    title: 'Cita cancelada',
    body: 'Paciente Uno cancelo su cita.',
    appointmentAt: new Date('2026-06-01T15:00:00.000Z'),
    sourceRole: 'patient',
    sourceUserId: 'p1',
    sendPush: true,
  });

  const persisted = db.store.get('notifications/admin_appointment_a1_cancelled_a1');
  assert.equal(persisted.recipientRole, 'admin');
  assert.equal(persisted.type, 'appointment_cancelled');
  assert.equal(persisted.targetRoute, '/admin/patients/p1?section=citas');
  assert.equal(persisted.delivery.status, 'skipped_no_active_tokens');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.equal(persisted.emailTo, 'admin@example.com');
  assert.deepEqual(persisted.channels, ['app', 'email']);
  assert.equal(persisted.payload.patientId, 'p1');
  assert.equal(persisted.payload.patientName, 'Paciente Uno');
  assert.equal(persisted.payload.appointmentId, 'a1');
});
