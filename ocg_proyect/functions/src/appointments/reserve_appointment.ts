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
const COLOMBIA_OFFSET_HOURS = 5; // UTC-5 => sumar 5 para UTC

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
  valoracion: {clinicalMinutes: 30, patientCanBook: true},
  control: {clinicalMinutes: 30, patientCanBook: true},
  instalacion: {clinicalMinutes: 30, patientCanBook: false},
  urgencia: {clinicalMinutes: 30, patientCanBook: false},
  alta: {clinicalMinutes: 30, patientCanBook: false},
};

/**
 * Parsea fecha (YYYY-MM-DD) y hora (HH:mm) como hora local de Bogotá (UTC-5, sin DST)
 * y devuelve el Date equivalente en UTC para almacenar correctamente en Firestore.
 */
function parseDateTime(date?: string, time?: string): Date {
  if (!date || !time) {
    throw new HttpsError('invalid-argument', 'Fecha y hora requeridas.');
  }
  const [y, m, d] = date.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  if (!y || !m || !d || Number.isNaN(hh) || Number.isNaN(mm)) {
    throw new HttpsError('invalid-argument', 'Formato de fecha/hora inválido.');
  }
  return new Date(Date.UTC(y, m - 1, d, hh + COLOMBIA_OFFSET_HOURS, mm, 0, 0));
}

function toBogotaParts(utcDate: Date): {year: number; month: number; day: number; weekday: number; hour: number; minute: number} {
  const bogota = new Date(utcDate.getTime() - COLOMBIA_OFFSET_HOURS * 60 * 60 * 1000);
  return {
    year: bogota.getUTCFullYear(),
    month: bogota.getUTCMonth() + 1,
    day: bogota.getUTCDate(),
    weekday: bogota.getUTCDay(),
    hour: bogota.getUTCHours(),
    minute: bogota.getUTCMinutes(),
  };
}

function validateWorkingHours(startAtUtc: Date, durationMinutes: number): void {
  const start = toBogotaParts(startAtUtc);
  const dayOfWeek = start.weekday;
  const blocks = SCHEDULE_BLOCKS[dayOfWeek] ?? [];

  if (blocks.length === 0) {
    throw new HttpsError('failed-precondition', 'La clínica no trabaja ese día.');
  }

  const endMinutes = start.hour * 60 + start.minute + durationMinutes;
  const fits = blocks.some((block) => {
    const blockStartMin = block.start * 60;
    const blockEndMin = block.end * 60;
    const startMinutes = start.hour * 60 + start.minute;
    return startMinutes >= blockStartMin && endMinutes <= blockEndMin;
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

  const startBogota = toBogotaParts(startAt);
  const dayStartUtc = new Date(Date.UTC(startBogota.year, startBogota.month - 1, startBogota.day, COLOMBIA_OFFSET_HOURS, 0, 0, 0));
  const dayEndUtc = new Date(Date.UTC(startBogota.year, startBogota.month - 1, startBogota.day + 1, COLOMBIA_OFFSET_HOURS, 0, 0, 0));

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(dayStartUtc))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(dayEndUtc))
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
    lastActionByRole: 'patient',
    lastActionBy: uid,
    notas: (request.data?.notes ?? '').toString(),
    recordatorio24hEnviado: false,
    recordatorio2hEnviado: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Rebuild usando día Bogotá normalizado.
  await rebuildAvailabilityForDay(new Date(Date.UTC(startBogota.year, startBogota.month - 1, startBogota.day, 0, 0, 0, 0)));

  return {
    ok: true,
    appointmentId: ref.id,
    clinicalMinutes,
    bufferMinutes: BUFFER_MINUTES,
    operationalMinutes,
  };
});
