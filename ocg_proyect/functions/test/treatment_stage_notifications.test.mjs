import test from 'node:test';
import assert from 'node:assert/strict';

import {
  handleTreatmentStageHistoryCreate,
} from '../lib/treatments/on_treatment_stage_history_create.js';
import {
  handleTreatmentStageChangeWrite,
} from '../lib/treatments/on_treatment_stage_change_write.js';

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
  constructor(db, path, filters = [], limitCount = null) {
    this.db = db;
    this.path = path;
    this.filters = filters;
    this.limitCount = limitCount;
  }

  where(field, op, value) {
    return new MockQuery(this.db, this.path, [...this.filters, {field, op, value}], this.limitCount);
  }

  limit(count) {
    return new MockQuery(this.db, this.path, this.filters, count);
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
      if (this.limitCount !== null && docs.length >= this.limitCount) break;
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

test('historial de tratamiento no primario envia email al paciente', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
  });

  const result = await handleTreatmentStageHistoryCreate(
    db,
    {patientId: 'p1', treatmentId: 't2', historyId: 'h1'},
    {
      etapaAnterior: 'valoracionInicial',
      etapaNueva: 'instalacion',
      treatmentId: 't2',
      notas: 'No debe ir al email.',
      diagnosticoBreve: 'No debe ir al email.',
    },
  );

  const persisted = db.store.get('notifications/stage_treatment_h1');
  assert.equal(result, 'notified');
  assert.equal(persisted.type, 'treatment_stage_updated');
  assert.equal(persisted.recipientRole, 'patient');
  assert.equal(persisted.treatmentId, 't2');
  assert.equal(persisted.delivery.status, 'skipped_no_active_tokens');
  assert.equal(persisted.emailStatus, 'sent');
  assert.equal(persisted.emailProvider, 'mock');
  assert.deepEqual(persisted.channels, ['app', 'email']);
  assert.equal(Object.hasOwn(persisted.payload, 'notas'), false);
  assert.equal(Object.hasOwn(persisted.payload, 'diagnosticoBreve'), false);
});

test('historial de tratamiento se omite si ya existe historial paciente equivalente', async () => {
  enableMockEmail();
  const db = new MockFirestore({
    'patients/p1': {id: 'p1', email: 'patient@example.com'},
    'patients/p1/stageHistory/root1': {
      etapaAnterior: 'valoracionInicial',
      etapaNueva: 'instalacion',
      treatmentId: 't2',
    },
  });

  const result = await handleTreatmentStageHistoryCreate(
    db,
    {patientId: 'p1', treatmentId: 't2', historyId: 'h2'},
    {
      etapaAnterior: 'valoracionInicial',
      etapaNueva: 'instalacion',
      treatmentId: 't2',
    },
  );

  assert.equal(result, 'skipped');
  assert.equal(db.store.has('notifications/stage_treatment_h2'), false);
});

test('cambio directo de etapa en tratamiento no primario crea historial', async () => {
  const db = new MockFirestore();

  const result = await handleTreatmentStageChangeWrite(
    db,
    {patientId: 'p1', treatmentId: 't2'},
    {etapaActual: 'valoracionInicial', isPrimary: false},
    {etapaActual: 'instalacion', isPrimary: false, updatedBy: 'admin1'},
  );

  const historyPath = [...db.store.keys()].find((path) =>
    path.startsWith('patients/p1/treatments/t2/stageHistory/'),
  );
  const history = historyPath ? db.store.get(historyPath) : null;

  assert.equal(result, 'created_history');
  assert.ok(historyPath);
  assert.equal(history.etapaAnterior, 'valoracionInicial');
  assert.equal(history.etapaNueva, 'instalacion');
  assert.equal(history.treatmentId, 't2');
});
