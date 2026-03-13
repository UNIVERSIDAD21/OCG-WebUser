import * as admin from 'firebase-admin';

type AppointmentLite = {
  estado?: string;
  fechaHora?: admin.firestore.Timestamp;
  duracionMinutos?: number;
};

const WORKDAY_START_HOUR = 8;
const WORKDAY_END_HOUR = 17;
const SLOT_MINUTES = 30;
const BUFFER_MINUTES = 10;

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

function buildBaseSlots(): Record<string, boolean> {
  const slots: Record<string, boolean> = {};
  for (let hour = WORKDAY_START_HOUR; hour < WORKDAY_END_HOUR; hour++) {
    for (const minute of [0, 30]) {
      const hh = hour.toString().padStart(2, '0');
      const mm = minute.toString().padStart(2, '0');
      slots[`${hh}:${mm}`] = true;
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

  const slots = buildBaseSlots();

  const appointments = snapshot.docs.map((d) => d.data() as AppointmentLite);
  for (const appt of appointments) {
    if (!isBlockingStatus(appt.estado) || !appt.fechaHora) continue;

    const startAt = appt.fechaHora.toDate();
    const duration = Math.max(15, Number(appt.duracionMinutos ?? 30));
    const endAt = new Date(startAt.getTime() + (duration + BUFFER_MINUTES) * 60000);

    for (const [label] of Object.entries(slots)) {
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

export function parseDayFromTimestamp(ts?: admin.firestore.Timestamp): Date | null {
  if (!ts) return null;
  const d = ts.toDate();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
