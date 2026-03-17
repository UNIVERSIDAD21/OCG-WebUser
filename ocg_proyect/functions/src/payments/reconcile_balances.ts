import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

export const reconcilePatientBalances = onCall(
  {region: 'us-central1', cors: true},
  async (request: CallableRequest<unknown>) => {
    const role = request.auth?.token?.role;
    if (role !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores pueden reconciliar saldos.');
    }

    const db = admin.firestore();
    const paymentsSnap = await db.collection('payments').get();

    let fixed = 0;
    let batch = db.batch();
    let ops = 0;

    for (const doc of paymentsSnap.docs) {
      const patientId = doc.id;
      const saldoPendiente = Number(doc.data().saldoPendiente ?? 0);

      batch.update(db.collection('patients').doc(patientId), {
        saldoPendiente,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      fixed += 1;
      ops += 1;

      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    return {
      fixed,
      message: `Reconciliación completada. ${fixed} paciente(s) sincronizados desde payments a patients.`,
    };
  },
);
