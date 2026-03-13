import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {rebuildAvailabilityForDay} from './availability';

type SeedAvailabilityData = {
  startDate?: string; // YYYY-MM-DD
  days?: number;
};

function requireAdmin(request: CallableRequest<SeedAvailabilityData>): void {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  const role = request.auth?.token?.role;
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo admin puede inicializar disponibilidad.');
  }
}

function parseStartDate(raw?: string): Date {
  if (!raw) {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  const [y, m, d] = raw.split('-').map(Number);
  if (!y || !m || !d) throw new HttpsError('invalid-argument', 'startDate inválida.');
  return new Date(y, m - 1, d, 0, 0, 0, 0);
}

export const seedAvailability = onCall<SeedAvailabilityData>(async (request) => {
  requireAdmin(request);

  const start = parseStartDate(request.data?.startDate);
  const totalDays = Math.min(120, Math.max(1, Number(request.data?.days ?? 30)));

  for (let i = 0; i < totalDays; i++) {
    const day = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i, 0, 0, 0, 0);
    await rebuildAvailabilityForDay(day);
  }

  return {
    ok: true,
    startDate: `${start.getFullYear()}-${(start.getMonth() + 1).toString().padStart(2, '0')}-${start.getDate().toString().padStart(2, '0')}`,
    days: totalDays,
  };
});
