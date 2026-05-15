import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type ReconcileNoShowData = {
  appointmentIds?: string[];
};

export const reconcileNoShowAppointments = onCall<ReconcileNoShowData>(
  async (request: CallableRequest<ReconcileNoShowData>) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Autenticación requerida.');
    }

    const ids = (request.data?.appointmentIds ?? [])
      .map((id) => id.toString().trim())
      .filter((id) => id.length > 0)
      .slice(0, 200);

    if (ids.length === 0) {
      return {ok: true, updated: 0, skipped: 0};
    }

    return {
      ok: true,
      updated: 0,
      skipped: ids.length,
      policy: 'manual_completion_required',
    };
  },
);
