import * as admin from 'firebase-admin';

type AppointmentLite = {
  estado?: string;
  fechaHora?: admin.firestore.Timestamp;
  duracionMinutos?: number;
};

const SLOT_MINUTES = 15;
const BUFFER_MINUTES = 10;
const COLOMBIA_UTC_OFFSET_HOURS = 5; // Bogotá UTC-5

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

function toDayKeyFromYmd(year: number, month: number, day: number): string {
  return `${year.toString().padStart(4, '0')}${month.toString().padStart(2, '0')}${day
    .toString()
    .padStart(2, '0')}`;
}

function toDateIsoFromYmd(year: number, month: number, day: number): string {
  return `${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-${day
    .toString()
    .padStart(2, '0')}`;
}

/** Date UTC -> partes en hora Bogotá. */
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

function buildBaseSlotsForWeekday(weekday: number): Record<string, boolean> {
  const slots: Record<string, boolean> = {};
  const blocks = SCHEDULE[weekday] ?? [];

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

/**
 * [day] debe venir normalizado como marcador UTC del día Bogotá (YYYY-MM-DD a las 00:00 UTC).
 */
export async function rebuildAvailabilityForDay(day: Date): Promise<void> {
  const db = admin.firestore();

  const year = day.getUTCFullYear();
  const month = day.getUTCMonth() + 1;
  const dom = day.getUTCDate();

  // Ventana UTC que corresponde al día calendario Bogotá [00:00, 24:00).
  const startUtc = new Date(Date.UTC(year, month - 1, dom, COLOMBIA_UTC_OFFSET_HOURS, 0, 0, 0));
  const endUtc = new Date(Date.UTC(year, month - 1, dom + 1, COLOMBIA_UTC_OFFSET_HOURS, 0, 0, 0));

  const snapshot = await db
    .collection('appointments')
    .where('fechaHora', '>=', admin.firestore.Timestamp.fromDate(startUtc))
    .where('fechaHora', '<', admin.firestore.Timestamp.fromDate(endUtc))
    .get();

  // Weekday real en Bogotá para ese Y-M-D.
  const weekday = new Date(
    Date.UTC(year, month - 1, dom, COLOMBIA_UTC_OFFSET_HOURS, 0, 0, 0),
  ).getUTCDay();

  const slots = buildBaseSlotsForWeekday(weekday);

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

  const dayKey = toDayKeyFromYmd(year, month, dom);
  await db.collection('availability').doc(dayKey).set(
    {
      date: toDateIsoFromYmd(year, month, dom),
      timezone: 'America/Bogota',
      slotDurationMinutes: SLOT_MINUTES,
      slots,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

/** Timestamp UTC de cita -> marcador UTC del día Bogotá (YYYY-MM-DD 00:00:00Z). */
export function parseDayFromTimestamp(ts?: admin.firestore.Timestamp): Date | null {
  if (!ts) return null;
  const p = toBogotaDateParts(ts.toDate());
  return new Date(Date.UTC(p.year, p.month - 1, p.day, 0, 0, 0, 0));
}
