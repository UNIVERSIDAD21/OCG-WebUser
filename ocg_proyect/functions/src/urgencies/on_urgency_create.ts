import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';

import {deliverNotification} from '../notifications/notification_delivery_service';

const URGENCY_ROUTE = '/admin/urgencies';
const RESOLVED_STATUSES = ['atendida', 'rechazada', 'reprogramada'];

function cleanString(value: unknown): string {
  return (value ?? '').toString().trim();
}

function truncate(text: string, maxLen: number): string {
  return text.length > maxLen ? `${text.slice(0, maxLen)}...` : text;
}

async function resolveAdminIds(
  db: FirebaseFirestore.Firestore,
): Promise<string[]> {
  const snapshot = await db.collection('admins').get();
  return snapshot.docs
    .filter((doc) => {
      const data = doc.data() ?? {};
      return data.role !== 'patient' &&
        data.admin !== false &&
        data.active !== false &&
        data.disabled !== true;
    })
    .map((doc) => doc.id)
    .filter((id) => id.trim().length > 0);
}

export const onUrgencyCreate = onDocumentCreated(
  'urgencyRequests/{requestId}',
  async (event) => {
    const db = admin.firestore();
    const requestId = event.params.requestId;
    const data = event.data?.data() ?? {};
    const patientName = cleanString(data.patientName) || 'Paciente';
    const patientId = cleanString(data.patientId);
    const descripcion = cleanString(data.descripcion);
    const body = `${patientName}: ${truncate(descripcion, 80)}`;
    const adminIds = await resolveAdminIds(db);

    logger.info('URGENCY_CREATE_NOTIFY_ADMINS', {
      requestId,
      patientId,
      admins: adminIds.length,
    });

    await Promise.all(
      adminIds.map((adminId) =>
        deliverNotification(db, {
          notificationId: `urgency_${requestId}_${adminId}`,
          recipientId: adminId,
          recipientRole: 'admin',
          title: 'Nueva solicitud de urgencia',
          body,
          type: 'urgency_request',
          targetRoute: URGENCY_ROUTE,
          entityId: requestId,
          entityType: 'urgency_request',
          data: {
            requestId,
            patientId,
            patientName,
            priority: 'high',
            channel_id: 'urgency_alerts',
          },
          source: 'trigger:urgency_request',
          channels: {
            app: true,
            email: false,
          },
        }),
      ),
    );
  },
);

export const archiveOldUrgencies = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'America/Bogota',
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 24 * 60 * 60 * 1000,
    );
    const snapshot = await db
      .collection('urgencyRequests')
      .where('estado', 'in', RESOLVED_STATUSES)
      .where('createdAt', '<', cutoff)
      .limit(300)
      .get();

    if (snapshot.empty) {
      logger.info('URGENCY_ARCHIVE_NOOP');
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        archived: true,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    logger.info('URGENCY_ARCHIVE_DONE', {count: snapshot.docs.length});
  },
);
