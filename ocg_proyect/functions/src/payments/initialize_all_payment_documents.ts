import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

export const initializeAllPaymentDocuments = onCall(
  {region: 'us-central1', cors: true},
  async (request: CallableRequest<unknown>) => {
    const role = request.auth?.token?.role;
    if (role !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores pueden inicializar pagos.');
    }

    const db = admin.firestore();
    const patientsSnap = await db.collection('patients').get();

    let created = 0;
    let ops = 0;
    let batch = db.batch();

    for (const patientDoc of patientsSnap.docs) {
      const patientId = patientDoc.id;
      const paymentRef = db.collection('payments').doc(patientId);
      const paymentDoc = await paymentRef.get();
      if (paymentDoc.exists) continue;

      const totalRaw = patientDoc.data()['totalTratamiento'];
      const totalTratamiento = typeof totalRaw === 'number' ? totalRaw : 0;
      const saldoPendiente = totalTratamiento;

      batch.set(paymentRef, {
        'id': patientId,
        'patientId': patientId,
        'totalTratamiento': totalTratamiento,
        'montoPagado': 0.0,
        'saldoPendiente': saldoPendiente,
        'fechaProximoPago': null,
        'estado': 'alDia',
        'createdAt': admin.firestore.FieldValue.serverTimestamp(),
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      created += 1;
      ops += 1;

      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    if (ops > 0) await batch.commit();

    return {
      created,
      message: `Inicialización completada. ${created} documento(s) de pagos creados.`,
    };
  },
);
