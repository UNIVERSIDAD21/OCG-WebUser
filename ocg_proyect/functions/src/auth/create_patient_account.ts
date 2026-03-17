import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type CreatePatientAccountData = {
  email?: string;
  password?: string;
  displayName?: string;
};

function assertAdmin(request: CallableRequest<CreatePatientAccountData>): void {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  const role = request.auth?.token?.role;
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores pueden crear cuentas de pacientes.');
  }
}

export const createPatientAccount = onCall<CreatePatientAccountData>(
  {region: 'us-central1'},
  async (request) => {
    assertAdmin(request);

    const email = request.data?.email?.trim().toLowerCase();
    const password = request.data?.password ?? '';
    const displayName = request.data?.displayName?.trim() ?? '';

    if (!email) throw new HttpsError('invalid-argument', 'Correo requerido.');
    if (password.length < 6) {
      throw new HttpsError('invalid-argument', 'Contraseña mínima de 6 caracteres.');
    }

    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().createUser({
        email,
        password,
        displayName: displayName.length == 0 ? undefined : displayName,
      });
    } catch (e: any) {
      if (e?.code === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Este correo ya tiene una cuenta registrada.');
      }
      throw e;
    }

    const now = new Date();

    try {
      // 1) Crear SIEMPRE el documento de paciente (fuente de verdad para la app)
      await admin.firestore().collection('patients').doc(user.uid).set(
        {
          id: user.uid,
          uid: user.uid,
          nombre: displayName,
          email,
          telefono: '',
          fechaNacimiento: admin.firestore.Timestamp.fromDate(now),
          fotoUrl: null,
          tipoTratamiento: null,
          etapaActual: 'diagnostico',
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

      // 2) Claim de rol (si falla, no dejamos el alta parcial)
      await admin.auth().setCustomUserClaims(user.uid, {role: 'patient'});

      return {
        ok: true,
        uid: user.uid,
        email,
      };
    } catch (e) {
      // Evitar cuentas huérfanas en Auth sin documento en patients.
      await admin.auth().deleteUser(user.uid).catch(() => undefined);
      throw e;
    }
  },
);
