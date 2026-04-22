import {onDocumentWritten} from 'firebase-functions/v2/firestore';

import * as admin from 'firebase-admin';

import {parseDayFromTimestamp, rebuildAvailabilityForDay} from './availability';
import {notifyAppointmentPatientChanges} from './appointment_patient_notifications';
import {syncAppointmentReminders} from './reminder_scheduler';

export const onAppointmentWrite = onDocumentWritten('appointments/{appointmentId}', async (event) => {
  const db = admin.firestore();
  const beforeData = event.data?.before.data() as any;
  const afterData = event.data?.after.data() as any;

  const beforeDay = parseDayFromTimestamp(beforeData?.fechaHora);
  const afterDay = parseDayFromTimestamp(afterData?.fechaHora);

  const rebuilds: Promise<void>[] = [];
  if (beforeDay) rebuilds.push(rebuildAvailabilityForDay(beforeDay));
  if (afterDay) {
    const sameDay = beforeDay && beforeDay.getTime() === afterDay.getTime();
    if (!sameDay) rebuilds.push(rebuildAvailabilityForDay(afterDay));
  }

  await Promise.all(rebuilds);

  if (afterData) {
    await Promise.all([
      syncAppointmentReminders(afterData as any),
      notifyAppointmentPatientChanges(db, {
        before: beforeData ?? null,
        after: afterData ?? null,
      }),
    ]);
  } else if (beforeData?.id && beforeData?.patientId) {
    await syncAppointmentReminders({
      id: beforeData.id,
      patientId: beforeData.patientId,
      estado: 'cancelada',
    } as any);
  }
});
