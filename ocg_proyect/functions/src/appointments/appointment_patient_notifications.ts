import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';

import {
  formatDateTimeBogota,
  notifyPatientAppointmentEvent,
} from '../notifications/domain_notifications';

function appointmentChangedMeaningfully(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
): boolean {
  if (!before || !after) return false;

  const beforeStatus = String(before.estado ?? '').trim();
  const afterStatus = String(after.estado ?? '').trim();
  const beforeAt = String((before.fechaHora as admin.firestore.Timestamp | undefined)?.toMillis?.() ?? '');
  const afterAt = String((after.fechaHora as admin.firestore.Timestamp | undefined)?.toMillis?.() ?? '');
  const beforeTreatmentId = String(before.treatmentId ?? '').trim();
  const afterTreatmentId = String(after.treatmentId ?? '').trim();

  return beforeStatus !== afterStatus || beforeAt !== afterAt || beforeTreatmentId !== afterTreatmentId;
}

export async function notifyAppointmentPatientChanges(
  db: FirebaseFirestore.Firestore,
  input: {
    before: Record<string, unknown> | null;
    after: Record<string, unknown> | null;
  },
): Promise<void> {
  const before = input.before;
  const after = input.after;

  if (!after) return;
  if (!appointmentChangedMeaningfully(before, after) && before) return;

  const appointmentId = String(after.id ?? '').trim();
  const patientId = String(after.patientId ?? '').trim();
  const treatmentId = String(after.treatmentId ?? '').trim();
  const currentStatus = String(after.estado ?? '').trim();

  if (!appointmentId || !patientId) return;

  logger.info('Evaluating appointment patient notification', {
    appointmentId,
    patientId,
    treatmentId,
    previousStatus: String(before?.estado ?? '').trim() || null,
    currentStatus,
    beforeAt: (before?.fechaHora as admin.firestore.Timestamp | undefined)?.toDate?.()?.toISOString?.() ?? null,
    afterAt: (after.fechaHora as admin.firestore.Timestamp | undefined)?.toDate?.()?.toISOString?.() ?? null,
  });

  if (!before) {
    await notifyPatientAppointmentEvent(db, {
      notificationId: `appointment_${appointmentId}_created`,
      patientId,
      appointmentId,
      treatmentId,
      type: 'appointment_created',
      title: 'Nueva cita agendada',
      body: `Tu cita fue agendada para ${formatDateTimeBogota(after.fechaHora)}.`,
      appointmentAt: after.fechaHora,
    });
    return;
  }

  const previousStatus = String(before.estado ?? '').trim();
  const beforeMillis = (before.fechaHora as admin.firestore.Timestamp | undefined)?.toMillis?.() ?? null;
  const afterMillis = (after.fechaHora as admin.firestore.Timestamp | undefined)?.toMillis?.() ?? null;
  const dateChanged = beforeMillis !== afterMillis;

  if (currentStatus === 'cancelada' && previousStatus !== 'cancelada') {
    await notifyPatientAppointmentEvent(db, {
      notificationId: `appointment_${appointmentId}_cancelled`,
      patientId,
      appointmentId,
      treatmentId,
      type: 'appointment_cancelled',
      title: 'Tu cita fue cancelada',
      body: `La cita prevista para ${formatDateTimeBogota(before.fechaHora ?? after.fechaHora)} fue cancelada.`,
      appointmentAt: after.fechaHora,
      previousAppointmentAt: before.fechaHora,
    });
    return;
  }

  const becameRescheduled = currentStatus === 'reprogramada' && previousStatus !== 'reprogramada';
  if (dateChanged || becameRescheduled) {
    await notifyPatientAppointmentEvent(db, {
      notificationId: `appointment_${appointmentId}_rescheduled_${afterMillis ?? 'na'}`,
      patientId,
      appointmentId,
      treatmentId,
      type: 'appointment_rescheduled',
      title: 'Tu cita fue reprogramada',
      body: `Tu cita cambió de ${formatDateTimeBogota(before.fechaHora)} a ${formatDateTimeBogota(after.fechaHora)}.`,
      appointmentAt: after.fechaHora,
      previousAppointmentAt: before.fechaHora,
    });
  }
}
