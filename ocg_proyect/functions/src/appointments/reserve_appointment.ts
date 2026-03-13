import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {rebuildAvailabilityForDay} from './availability';

type ReserveAppointmentData = {
  date?: string; // YYYY-MM-DD
  time?: string; // HH:mm
  durationMinutes?: number;
  type?: string;
  notes?: string;
};

const WORKDAY_START_HOUR = 8;
const WORKDAY_END_HOUR = 17;
const BUFFER_MINUTES = 10;

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
  const endAt = new Date(startAt.getTime() + durationMinutes * 60000);
  const startLimit = new Date(
    startAt.getFullYear(),
    startAt.getMonth(),
    startAt.getDate(),
    WORKDAY_START_HOUR,
    0,
    0,
    0,
  );
  const endLimit = new Date(
    startAt.getFullYear(),
    startAt.getMonth(),
    startAt.getDate(),
    WORKDAY_END_HOUR,
    0,
    0,
    0,
  );
  if (startAt < startLimit || endAt > endLimit) {
    throw new HttpsError('failed-precondition', 'Solo se permiten citas entre 08:00 y 17:00.');
  }
}

export const reserveAppointment = onCall<ReserveAppointmentData>(async (request: CallableRequest<ReserveAppointmentData>) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const durationMinutes = Math.max(15, Number(request.data?.durationMinutes ?? 30));
  const startAt = parseDateTime(request.data?.date, request.data?.time);
  validateWorkingHours(startAt, durationMinutes);

  const db = admin.firestore();
  const dayStart = new Date(startAt.getFullYear(), startAt.getMonth(), startAt.getDate(), 0, 0, 0, 0);
  const dayEnd = new Date(startAt.getFullYear(), startAt.getMonth(), startAt.getDate() + 1, 0, 0, 0, 0);

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(dayStart))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(dayEnd))
    .get();

  const newEnd = new Date(startAt.getTime() + durationMinutes * 60000);
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
    tipo: (request.data?.type ?? 'control').toString(),
    estado: 'programada',
    fechaHora: admin.firestore.Timestamp.fromDate(startAt),
    duracionMinutos: durationMinutes,
    creadoPor: uid,
    notas: (request.data?.notes ?? '').toString(),
    recordatorio24hEnviado: false,
    recordatorio2hEnviado: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await rebuildAvailabilityForDay(dayStart);

  return {ok: true, appointmentId: ref.id};
});
