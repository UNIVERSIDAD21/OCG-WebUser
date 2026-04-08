import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type DeletePatientAccountData = {
  patientId?: string;
};

function assertAdmin(request: CallableRequest<DeletePatientAccountData>): void {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  if (request.auth?.token?.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores pueden eliminar pacientes.');
  }
}

export const deletePatientAccount = onCall<DeletePatientAccountData>(
  {region: 'us-central1'},
  async (request) => {
    assertAdmin(request);

    const patientId = request.data?.patientId?.trim();
    if (!patientId) throw new HttpsError('invalid-argument', 'patientId es requerido.');

    const db = admin.firestore();

    // Borra perfil y pagos base
    await Promise.all([
      db.collection('patients').doc(patientId).delete().catch(() => undefined),
      db.collection('payments').doc(patientId).delete().catch(() => undefined),
    ]);

    // Borra transacciones de pagos del paciente
    const txSnap = await db.collection('payments').doc(patientId).collection('transactions').get();
    const txBatch = db.batch();
    for (const doc of txSnap.docs) txBatch.delete(doc.ref);
    if (!txSnap.empty) await txBatch.commit();

    // Borra citas del paciente
    const appts = await db.collection('appointments').where('patientId', '==', patientId).get();
    if (!appts.empty) {
      const batch = db.batch();
      for (const doc of appts.docs) batch.delete(doc.ref);
      await batch.commit();
    }

    // Elimina usuario en Firebase Auth para liberar correo
    await admin.auth().deleteUser(patientId).catch((e: any) => {
      if (e?.code !== 'auth/user-not-found') throw e;
    });

    return {ok: true, patientId};
  },
);
