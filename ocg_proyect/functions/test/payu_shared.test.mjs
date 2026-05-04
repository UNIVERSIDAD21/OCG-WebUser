import test from 'node:test';
import assert from 'node:assert/strict';

import {normalizePayuState} from '../lib/payments/payu_shared.js';

test('normalizePayuState mapea aprobado/rechazado/pendiente', () => {
  assert.equal(normalizePayuState(4), 'aprobado');
  assert.equal(normalizePayuState(6), 'rechazado');
  assert.equal(normalizePayuState(7), 'pendiente_confirmacion');
  assert.equal(normalizePayuState(999), 'state_999');
});
