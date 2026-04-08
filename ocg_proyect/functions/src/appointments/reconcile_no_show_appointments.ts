import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type ReconcileNoShowData = {
  appointmentIds?: string[];
};

const ALLOWED_CURRENT = new Set(['programada', 'confirmada']);
const BLOCKING_FINAL = new Set(['completada', 'cancelada', 'reprogramada', 'noAsistio']);

export const reconcileNoShowAppointments = onCall<ReconcileNoShowData>(
  async (request: CallableRequest<ReconcileNoShowData>) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Autenticación requerida.');
    }

    const ids = (request.data?.appointmentIds ?? [])
      .map((id) => id.toString().trim())
      .where((id) => id.isNotEmpty)
      .slice(0, 200);

    if (ids.isEmpty) {
      return {ok: true, updated: 0};
    }

    const db = admin.firestore();
    const now = new Date();

    let updated = 0;

    for (const id of ids) {
      const ref = db.collection('appointments').doc(id);
      const snap = await ref.get();
      if (!snap.exists) continue;

      const data = snap.data() as any;
      const estado = (data?.estado ?? '').toString();
      if (BLOCKING_FINAL.has(estado) || !ALLOWED_CURRENT.has(estado)) continue;

      const fechaTs = data?.fechaHora as admin.firestore.Timestamp | undefined;
      if (!fechaTs) continue;

      const duracion = Number(data?.duracionMinutos ?? 30);
      const endAt = new Date(fechaTs.toDate().getTime() + duracion * 60 * 1000);
      if (endAt >= now) continue;

      await ref.update({
        estado: 'noAsistio',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated++;
    }

    return {ok: true, updated};
  },
);
