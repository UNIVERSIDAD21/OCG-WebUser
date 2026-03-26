import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type RegisterPatientSelfData = {
  email?: string;
  password?: string;
  displayName?: string;
};

export const registerPatientSelf = onCall<RegisterPatientSelfData>(
  {region: 'us-central1'},
  async (request: CallableRequest<RegisterPatientSelfData>) => {
    const email = request.data?.email?.trim().toLowerCase();
    const password = request.data?.password ?? '';
    const displayName = request.data?.displayName?.trim() ?? '';

    if (!email) throw new HttpsError('invalid-argument', 'Correo requerido.');
    if (password.length < 6) {
      throw new HttpsError('invalid-argument', 'Contraseña mínima de 6 caracteres.');
    }

    const db = admin.firestore();

    const patientByEmail = await db.collection('patients').where('email', '==', email).limit(1).get();
    if (!patientByEmail.empty) {
      throw new HttpsError('already-exists', 'Este correo ya está en uso.');
    }

    const adminByEmail = await db.collection('admins').where('email', '==', email).limit(1).get();
    if (!adminByEmail.empty) {
      throw new HttpsError('already-exists', 'Este correo ya está en uso.');
    }

    // Si existe en Auth pero no en BD (cuenta huérfana), eliminar y reutilizar correo.
    try {
      const authUser = await admin.auth().getUserByEmail(email);
      const patientDoc = await db.collection('patients').doc(authUser.uid).get();
      const adminDoc = await db.collection('admins').doc(authUser.uid).get();

      if (patientDoc.exists || adminDoc.exists) {
        throw new HttpsError('already-exists', 'Este correo ya está en uso.');
      }

      await admin.auth().deleteUser(authUser.uid);
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      if (e?.code !== 'auth/user-not-found') throw e;
    }

    const user = await admin.auth().createUser({
      email,
      password,
      displayName: displayName.length === 0 ? undefined : displayName,
    });

    const now = new Date();

    try {
      await admin.auth().setCustomUserClaims(user.uid, {role: 'patient'});

      await db.collection('patients').doc(user.uid).set(
        {
          id: user.uid,
          uid: user.uid,
          nombre: displayName,
          email,
          telefono: '',
          fechaNacimiento: admin.firestore.Timestamp.fromDate(now),
          fotoUrl: null,
          tipoTratamiento: null,
          etapaActual: 'valoracionInicial',
          fechaInicio: admin.firestore.Timestamp.fromDate(now),
          fechaEstimadaFin: null,
          notasClinicas: '',
          totalTratamiento: 0,
          saldoPendiente: 0,
          fechaProximoPago: null,
          proximaCita: null,
          fcmToken: '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {ok: true, uid: user.uid, email};
    } catch (e) {
      await admin.auth().deleteUser(user.uid).catch(() => undefined);
      throw e;
    }
  },
);
