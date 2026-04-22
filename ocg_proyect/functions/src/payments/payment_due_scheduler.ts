import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';
import {onSchedule} from 'firebase-functions/v2/scheduler';

import {
  formatCop,
  formatDateBogota,
  notifyPatientPaymentEvent,
} from '../notifications/domain_notifications';

function db(): FirebaseFirestore.Firestore {
  return admin.firestore();
}
const BOGOTA_TIME_ZONE = 'America/Bogota';
const DAY_MS = 24 * 60 * 60 * 1000;

function startOfBogotaDay(date: Date): Date {
  const label = new Intl.DateTimeFormat('en-CA', {
    timeZone: BOGOTA_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
  const [year, month, day] = label.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day, 5, 0, 0, 0));
}

function diffInBogotaDays(dueDate: Date, now: Date): number {
  const dueStart = startOfBogotaDay(dueDate).getTime();
  const nowStart = startOfBogotaDay(now).getTime();
  return Math.round((dueStart - nowStart) / DAY_MS);
}

export const processPaymentDueNotifications = onSchedule(
  {
    schedule: '0 12 * * *',
    timeZone: BOGOTA_TIME_ZONE,
    region: 'us-central1',
  },
  async () => {
    const now = new Date();
    const paymentsSnap = await db().collection('payments').get();

    for (const doc of paymentsSnap.docs) {
      const payment = doc.data() ?? {};
      const patientId = String(payment.patientId ?? doc.id).trim();
      const saldoPendiente = Number(payment.saldoPendiente ?? 0);
      const dueTs = payment.fechaProximoPago as admin.firestore.Timestamp | undefined;
      const dueDate = dueTs?.toDate();

      if (!patientId || !dueDate || !Number.isFinite(saldoPendiente) || saldoPendiente <= 0) {
        continue;
      }

      const daysUntilDue = diffInBogotaDays(dueDate, now);
      if (daysUntilDue !== 3) continue;

      const reminderKey = `${patientId}_${startOfBogotaDay(dueDate).toISOString().slice(0, 10)}`;

      logger.info('Processing payment due notification', {
        patientId,
        paymentId: doc.id,
        saldoPendiente,
        dueDate: dueDate.toISOString(),
        daysUntilDue,
        reminderKey,
      });

      await notifyPatientPaymentEvent(db(), {
        notificationId: `payment_due_${reminderKey}`,
        patientId,
        paymentId: doc.id,
        treatmentId: String(payment.treatmentId ?? '').trim(),
        type: 'payment_due',
        title: 'Tienes un pago próximo a vencer',
        body: `Tu próximo pago vence el ${formatDateBogota(dueDate)}. Saldo pendiente: ${formatCop(saldoPendiente)}.`,
        amount: saldoPendiente,
        dueDate,
      });
    }
  },
);
