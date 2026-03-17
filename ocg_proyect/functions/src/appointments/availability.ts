import * as admin from 'firebase-admin';

type AppointmentLite = {
  estado?: string;
  fechaHora?: admin.firestore.Timestamp;
  duracionMinutos?: number;
};

const SLOT_MINUTES = 15;
const BUFFER_MINUTES = 10;
const COLOMBIA_UTC_OFFSET_HOURS = 5; // Bogotá (UTC-5) => local +5 = UTC

/** Bloques horarios por día de semana (getDay(): 0=Dom, 1=Lun … 6=Sab) */
const SCHEDULE: Record<number, Array<{start: number; end: number}>> = {
  1: [{start: 8, end: 12}, {start: 14, end: 18}],
  2: [{start: 8, end: 12}, {start: 14, end: 18}],
  3: [{start: 8, end: 12}, {start: 14, end: 18}],
  4: [{start: 8, end: 12}, {start: 14, end: 18}],
  5: [{start: 8, end: 12}, {start: 14, end: 18}],
  6: [{start: 8, end: 12}],
  0: [],
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

/** Convierte un Date UTC a componentes de fecha/hora de Bogotá. */
function toBogotaDateParts(utcDate: Date): {
  year: number;
  month: number;
  day: number;
  weekday: number;
  hour: number;
  minute: number;
} {
  const bogota = new Date(utcDate.getTime() - COLOMBIA_UTC_OFFSET_HOURS * 60 * 60 * 1000);
  return {
    year: bogota.getUTCFullYear(),
    month: bogota.getUTCMonth() + 1,
    day: bogota.getUTCDate(),
    weekday: bogota.getUTCDay(),
    hour: bogota.getUTCHours(),
    minute: bogota.getUTCMinutes(),
  };
}

/** Construye UTC date desde fecha/hora de Bogotá. */
function bogotaToUtcDate(year: number, month: number, day: number, hour = 0, minute = 0): Date {
  return new Date(Date.UTC(year, month - 1, day, hour + COLOMBIA_UTC_OFFSET_HOURS, minute, 0, 0));
}

/** Construye el mapa base de slots para el día dado según el horario de la clínica (hora Bogotá). */
function buildBaseSlots(day: Date): Record<string, boolean> {
  const slots: Record<string, boolean> = {};
  const parts = toBogotaDateParts(day);
  const blocks = SCHEDULE[parts.weekday] ?? [];

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

  // El parámetro day representa día calendario de Bogotá.
  const d = toBogotaDateParts(day);
  const startUtc = bogotaToUtcDate(d.year, d.month, d.day, 0, 0);
  const endUtc = bogotaToUtcDate(d.year, d.month, d.day + 1, 0, 0);

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(startUtc))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(endUtc))
    .get();

  const slots = buildBaseSlots(day);

  const appointments = snapshot.docs.map((doc) => doc.data() as AppointmentLite);
  for (const appt of appointments) {
    if (!isBlockingStatus(appt.estado) || !appt.fechaHora) continue;

    const startAtUtc = appt.fechaHora.toDate();
    const startBogota = toBogotaDateParts(startAtUtc);

    const startMinutes = startBogota.hour * 60 + startBogota.minute;
    const duration = Math.max(15, Number(appt.duracionMinutos ?? 30));
    const endMinutes = startMinutes + duration + BUFFER_MINUTES;

    for (const label of Object.keys(slots)) {
      const [hh, mm] = label.split(':').map(Number);
      const slotStartMinutes = hh * 60 + mm;
      const slotEndMinutes = slotStartMinutes + SLOT_MINUTES;
      const overlaps = slotStartMinutes < endMinutes && startMinutes < slotEndMinutes;
      if (overlaps) slots[label] = false;
    }
  }

  const dayKey = `${d.year.toString().padStart(4, '0')}${d.month.toString().padStart(2, '0')}${d.day.toString().padStart(2, '0')}`;
  await db.collection('availability').doc(dayKey).set(
    {
      date: `${d.year.toString().padStart(4, '0')}-${d.month.toString().padStart(2, '0')}-${d.day.toString().padStart(2, '0')}`,
      timezone: 'America/Bogota',
      slotDurationMinutes: SLOT_MINUTES,
      slots,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

export function parseDayFromTimestamp(ts?: admin.firestore.Timestamp): Date | null {
  if (!ts) return null;
  const p = toBogotaDateParts(ts.toDate());
  // Día Bogotá normalizado (00:00) para reusar en rebuildAvailabilityForDay.
  return new Date(Date.UTC(p.year, p.month - 1, p.day, 0, 0, 0, 0));
}
