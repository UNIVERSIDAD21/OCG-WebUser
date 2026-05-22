import test from 'node:test';
import assert from 'node:assert/strict';

import {shouldAutoMarkNoShow} from '../lib/appointments/reconcile_no_show_appointments.js';

test('marca automaticamente cita abierta al cumplirse 24 h despues del fin', () => {
  const appointment = {
    estado: 'programada',
    fechaHora: new Date('2026-05-20T10:00:00.000Z'),
    duracionMinutos: 30,
  };
  const now = new Date('2026-05-21T10:30:00.000Z');

  assert.equal(shouldAutoMarkNoShow(appointment, now), true);
});

test('no marca cita abierta antes de completar la ventana de 24 h', () => {
  const appointment = {
    estado: 'confirmada',
    fechaHora: new Date('2026-05-20T10:00:00.000Z'),
    duracionMinutos: 30,
  };
  const now = new Date('2026-05-21T10:29:59.000Z');

  assert.equal(shouldAutoMarkNoShow(appointment, now), false);
});

test('no marca citas que ya estan cerradas administrativamente', () => {
  const base = {
    fechaHora: new Date('2026-05-20T10:00:00.000Z'),
    duracionMinutos: 30,
  };
  const now = new Date('2026-05-22T10:30:00.000Z');

  assert.equal(shouldAutoMarkNoShow({...base, estado: 'completada'}, now), false);
  assert.equal(shouldAutoMarkNoShow({...base, estado: 'cancelada'}, now), false);
  assert.equal(shouldAutoMarkNoShow({...base, estado: 'reprogramada'}, now), false);
});
