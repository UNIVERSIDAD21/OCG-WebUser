import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {rebuildAvailabilityForDay} from './availability';

type ReserveAppointmentData = {
  date?: string; // YYYY-MM-DD
  time?: string; // HH:mm
  type?: string;
  notes?: string;
};

const BUFFER_MINUTES = 10;

/** Bloques horarios por día (getDay(): 0=Dom … 6=Sab) */
const SCHEDULE_BLOCKS: Record<number, Array<{start: number; end: number}>> = {
  1: [{start: 8, end: 12}, {start: 14, end: 18}],
  2: [{start: 8, end: 12}, {start: 14, end: 18}],
  3: [{start: 8, end: 12}, {start: 14, end: 18}],
  4: [{start: 8, end: 12}, {start: 14, end: 18}],
  5: [{start: 8, end: 12}, {start: 14, end: 18}],
  6: [{start: 8, end: 12}],
  0: [],
};

const APPOINTMENT_TYPE_CONFIG: Record<string, {clinicalMinutes: number; patientCanBook: boolean}> = {
  valoracion: {clinicalMinutes: 50, patientCanBook: true},
  control: {clinicalMinutes: 30, patientCanBook: true},
  instalacion: {clinicalMinutes: 60, patientCanBook: false},
  urgencia: {clinicalMinutes: 40, patientCanBook: false},
  alta: {clinicalMinutes: 30, patientCanBook: false},
};

function parseDateTime(date?: string, time?: string): Date {
  if (!date || !time) {
    throw new HttpsError('invalid-argument', 'Fecha y hora requeridas.');
  }
  const [y, m, d] = date.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  if (!y || !m || !d || Number.isNaN(hh) || Number.isNaN(mm)) {
    throw new HttpsError('invalid-argument', 'Formato de fecha/hora inválido.');
  }
  return new Date(y, m - 1, d, hh, mm, 0, 0);
}

function validateWorkingHours(startAt: Date, durationMinutes: number): void {
  const dayOfWeek = startAt.getDay();
  const blocks = SCHEDULE_BLOCKS[dayOfWeek] ?? [];
  if (blocks.length === 0) {
    throw new HttpsError('failed-precondition', 'La clínica no trabaja ese día.');
  }

  const endAt = new Date(startAt.getTime() + durationMinutes * 60000);
  const fits = blocks.some((block) => {
    const blockStart = new Date(
      startAt.getFullYear(),
      startAt.getMonth(),
      startAt.getDate(),
      block.start,
      0,
      0,
      0,
    );
    const blockEnd = new Date(
      startAt.getFullYear(),
      startAt.getMonth(),
      startAt.getDate(),
      block.end,
      0,
      0,
      0,
    );

    return startAt >= blockStart && endAt <= blockEnd;
  });

  if (!fits) {
    throw new HttpsError(
      'failed-precondition',
      'Solo se permiten citas dentro del horario laboral de la clínica.',
    );
  }
}

export const reserveAppointment = onCall<ReserveAppointmentData>(async (request: CallableRequest<ReserveAppointmentData>) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const type = (request.data?.type ?? 'control').toString();
  const typeConfig = APPOINTMENT_TYPE_CONFIG[type];
  if (!typeConfig) {
    throw new HttpsError('invalid-argument', 'Tipo de cita inválido.');
  }
  if (!typeConfig.patientCanBook) {
    throw new HttpsError('permission-denied', 'Este tipo de cita solo puede agendarlo la clínica.');
  }

  const clinicalMinutes = typeConfig.clinicalMinutes;
  const operationalMinutes = clinicalMinutes + BUFFER_MINUTES;
  const startAt = parseDateTime(request.data?.date, request.data?.time);
  validateWorkingHours(startAt, operationalMinutes);

  const db = admin.firestore();
  const dayStart = new Date(startAt.getFullYear(), startAt.getMonth(), startAt.getDate(), 0, 0, 0, 0);
  const dayEnd = new Date(startAt.getFullYear(), startAt.getMonth(), startAt.getDate() + 1, 0, 0, 0, 0);

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(dayStart))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(dayEnd))
    .get();

  const newEnd = new Date(startAt.getTime() + operationalMinutes * 60000);
  const hasConflict = snapshot.docs.some((doc) => {
    const data = doc.data() as any;
    const estado = data.estado as string | undefined;
    if (estado === 'cancelada' || estado === 'noAsistio' || estado === 'reprogramada') {
      return false;
    }
    const existingStart = (data.fechaHora as admin.firestore.Timestamp).toDate();
    const existingEnd = new Date(existingStart.getTime() + (Number(data.duracionMinutos ?? 30) + BUFFER_MINUTES) * 60000);
    return startAt < existingEnd && existingStart < newEnd;
  });

  if (hasConflict) {
    throw new HttpsError('failed-precondition', 'Ese horario ya está ocupado.');
  }

  const patientDoc = await db.collection('patients').doc(uid).get();
  const patient = patientDoc.data() ?? {};

  const ref = db.collection('appointments').doc();
  await ref.set({
    id: ref.id,
    patientId: uid,
    patientName: (patient.nombre ?? '').toString(),
    patientPhone: (patient.telefono ?? '').toString(),
    tipo: type,
    estado: 'programada',
    fechaHora: admin.firestore.Timestamp.fromDate(startAt),
    duracionMinutos: clinicalMinutes,
    bufferMinutos: BUFFER_MINUTES,
    creadoPor: uid,
    notas: (request.data?.notes ?? '').toString(),
    recordatorio24hEnviado: false,
    recordatorio2hEnviado: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await rebuildAvailabilityForDay(dayStart);

  return {
    ok: true,
    appointmentId: ref.id,
    clinicalMinutes,
    bufferMinutes: BUFFER_MINUTES,
    operationalMinutes,
  };
});
