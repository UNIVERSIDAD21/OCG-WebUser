import * as admin from 'firebase-admin';

type AppointmentLite = {
  estado?: string;
  fechaHora?: admin.firestore.Timestamp;
  duracionMinutos?: number;
};

const SLOT_MINUTES = 15;
const BUFFER_MINUTES = 10;

/** Bloques horarios por día de semana (getDay(): 0=Dom, 1=Lun … 6=Sab) */
const SCHEDULE: Record<number, Array<{start: number; end: number}>> = {
  1: [{start: 8, end: 12}, {start: 14, end: 18}], // Lunes
  2: [{start: 8, end: 12}, {start: 14, end: 18}], // Martes
  3: [{start: 8, end: 12}, {start: 14, end: 18}], // Miércoles
  4: [{start: 8, end: 12}, {start: 14, end: 18}], // Jueves
  5: [{start: 8, end: 12}, {start: 14, end: 18}], // Viernes
  6: [{start: 8, end: 12}], // Sábado
  0: [], // Domingo cerrado
};

function toDayKey(date: Date): string {
  const y = date.getFullYear().toString().padStart(4, '0');
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  return `${y}${m}${d}`;
}

function toDateIso(date: Date): string {
  const y = date.getFullYear().toString().padStart(4, '0');
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Construye el mapa base de slots para el día dado según el horario de la clínica. */
function buildBaseSlots(day: Date): Record<string, boolean> {
  const slots: Record<string, boolean> = {};
  const dayOfWeek = day.getDay();
  const blocks = SCHEDULE[dayOfWeek] ?? [];

  for (const block of blocks) {
    for (let hour = block.start; hour < block.end; hour++) {
      for (let minute = 0; minute < 60; minute += SLOT_MINUTES) {
        const hh = hour.toString().padStart(2, '0');
        const mm = minute.toString().padStart(2, '0');
        slots[`${hh}:${mm}`] = true;
      }
    }
  }

  return slots;
}

function isBlockingStatus(status?: string): boolean {
  return status !== 'cancelada' && status !== 'noAsistio' && status !== 'reprogramada';
}

export async function rebuildAvailabilityForDay(day: Date): Promise<void> {
  const db = admin.firestore();
  const start = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0, 0);
  const end = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1, 0, 0, 0, 0);

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(end))
    .get();

  const slots = buildBaseSlots(day);

  const appointments = snapshot.docs.map((d) => d.data() as AppointmentLite);
  for (const appt of appointments) {
    if (!isBlockingStatus(appt.estado) || !appt.fechaHora) continue;

    const startAt = appt.fechaHora.toDate();
    const duration = Math.max(15, Number(appt.duracionMinutos ?? 30));
    const endAt = new Date(startAt.getTime() + (duration + BUFFER_MINUTES) * 60000);

    for (const label of Object.keys(slots)) {
      const [hh, mm] = label.split(':').map((n) => Number(n));
      const slotStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), hh, mm, 0, 0);
      const slotEnd = new Date(slotStart.getTime() + SLOT_MINUTES * 60000);
      const overlaps = slotStart < endAt && startAt < slotEnd;
      if (overlaps) slots[label] = false;
    }
  }

  const dayKey = toDayKey(day);
  await db.collection('availability').doc(dayKey).set(
    {
      date: toDateIso(day),
      timezone: 'America/Bogota',
      slotDurationMinutes: SLOT_MINUTES,
      slots,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

export function parseDayFromTimestamp(ts: admin.firestore.Timestamp): Date {
  const d = ts.toDate();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
