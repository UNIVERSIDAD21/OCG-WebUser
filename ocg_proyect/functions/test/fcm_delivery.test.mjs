import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildFcmMessageForDevice,
  deactivateDeviceToken,
  resolveActiveDeviceTokens,
  sendFcmNotification,
} from '../lib/notifications/fcm_delivery.js';

class MockDocSnapshot {
  constructor(path, data) { this.path = path; this.id = path.split('/').pop(); this._data = data; this.exists = data !== undefined; }
  data() { return this._data; }
}
class MockDocRef {
  constructor(db, path) { this.db = db; this.path = path; this.id = path.split('/').pop(); }
  collection(name) { return new MockCollectionRef(this.db, `${this.path}/${name}`); }
  async get() { return new MockDocSnapshot(this.path, this.db.store.get(this.path)); }
  async set(data, options = {}) {
    const material = materialize(data);
    const prev = this.db.store.get(this.path);
    this.db.store.set(this.path, options.merge && prev ? deepMerge(prev, material) : material);
  }
}
class MockQuerySnapshot { constructor(docs) { this.docs = docs; this.empty = docs.length === 0; } }
class MockQuery {
  constructor(db, path, filters = []) { this.db = db; this.path = path; this.filters = filters; }
  where(field, op, value) { return new MockQuery(this.db, this.path, [...this.filters, {field, op, value}]); }
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
  constructor(db, path) { super(db, path); this.path = path; }
  doc(id) { return new MockDocRef(this.db, `${this.path}/${id}`); }
}
class MockFirestore { constructor(seed = {}) { this.store = new Map(Object.entries(seed)); } collection(path) { return new MockCollectionRef(this, path); } }

function materialize(value) {
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = typeof v === 'function' ? '[FieldValue]' : materialize(v);
    return out;
  }
  return value;
}
function deepMerge(a, b) {
  const out = {...a};
  for (const [k, v] of Object.entries(b)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && a[k] && typeof a[k] === 'object' && !Array.isArray(a[k])) out[k] = deepMerge(a[k], v);
    else out[k] = v;
  }
  return out;
}

function seed() {
  return {
    'patients/p1': {id: 'p1', fcmToken: 'legacy-token', fcmDeviceId: 'legacy-top', fcmPlatform: 'ios'},
    'patients/p1/devices/d-android': {token: 'android-token', platform: 'android', active: true},
    'patients/p1/devices/d-ios': {token: 'ios-token', platform: 'ios', active: true},
    'patients/p1/devices/d-ios-dup': {token: 'ios-token', platform: 'ios', active: true},
  };
}

test('resuelve token Android activo', async () => {
  const db = new MockFirestore(seed());
  const tokens = await resolveActiveDeviceTokens(db, 'patient', 'p1', ['android']);
  assert.equal(tokens.length, 1);
  assert.equal(tokens[0].platform, 'android');
});

test('resuelve token iOS activo', async () => {
  const db = new MockFirestore(seed());
  const tokens = await resolveActiveDeviceTokens(db, 'patient', 'p1', ['ios']);
  assert.equal(tokens.length, 2);
  assert.equal(tokens.some((t) => t.token === 'ios-token'), true);
  assert.equal(tokens.some((t) => t.token === 'legacy-token'), true);
});

test('resuelve ambos tokens y deduplica', async () => {
  const db = new MockFirestore(seed());
  const tokens = await resolveActiveDeviceTokens(db, 'patient', 'p1', ['android', 'ios']);
  assert.equal(tokens.length, 3);
});

test('si no hay tokens activos retorna skipped_no_active_tokens', async () => {
  const db = new MockFirestore({'patients/p1': {id: 'p1'}});
  const result = await sendFcmNotification(db, {
    recipientId: 'p1', recipientRole: 'patient', title: 'Hola', body: 'Body', type: 'payment_due',
  }, {send: async () => 'never'});
  assert.equal(result.status, 'skipped_no_active_tokens');
});

test('construye payload Android con channelId', () => {
  const message = buildFcmMessageForDevice(
    {recipientId: 'p1', recipientRole: 'patient', title: 'T', body: 'B', type: 'x'},
    {id: 'd1', token: 'a', source: 'devices', active: true, platform: 'android'},
  );
  assert.equal(message.android.notification.channelId, 'ocg_clinica_push');
});

test('construye payload iOS con apns sound default', () => {
  const message = buildFcmMessageForDevice(
    {recipientId: 'p1', recipientRole: 'patient', title: 'T', body: 'B', type: 'x'},
    {id: 'd1', token: 'i', source: 'devices', active: true, platform: 'ios'},
  );
  assert.equal(message.apns.payload.aps.sound, 'default');
});

test('token inválido Android se desactiva', async () => {
  const db = new MockFirestore({'patients/p1': {id: 'p1'}, 'patients/p1/devices/d1': {token: 'bad-android', platform: 'android', active: true}});
  const result = await sendFcmNotification(
    db,
    {recipientId: 'p1', recipientRole: 'patient', title: 'T', body: 'B', type: 'x'},
    {send: async () => { const e = new Error('bad'); e.code = 'messaging/registration-token-not-registered'; throw e; }},
  );
  assert.equal(result.failureCount, 1);
  assert.equal(db.store.get('patients/p1/devices/d1').active, false);
});

test('token inválido iOS se desactiva', async () => {
  const db = new MockFirestore({'patients/p1': {id: 'p1'}, 'patients/p1/devices/d1': {token: 'bad-ios', platform: 'ios', active: true}});
  const result = await sendFcmNotification(
    db,
    {recipientId: 'p1', recipientRole: 'patient', title: 'T', body: 'B', type: 'x'},
    {send: async () => { const e = new Error('bad'); e.code = 'messaging/invalid-registration-token'; throw e; }},
  );
  assert.equal(result.failureCount, 1);
  assert.equal(db.store.get('patients/p1/devices/d1').active, false);
});

test('legacy top-level token sigue funcionando', async () => {
  const db = new MockFirestore({'patients/p1': {id: 'p1', fcmToken: 'legacy-token', fcmPlatform: 'ios'}});
  const tokens = await resolveActiveDeviceTokens(db, 'patient', 'p1', ['ios']);
  assert.equal(tokens.length, 1);
  assert.equal(tokens[0].source, 'legacy_top_level');
});
