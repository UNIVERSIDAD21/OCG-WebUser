import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type CreatePatientAccountData = {
  email?: string;
  password?: string;
  displayName?: string;
};

function isActiveUserDoc(data: admin.firestore.DocumentData | undefined): boolean {
  if (!data) return false;
  const deletedAt = data.deletedAt;
  const activo = data.activo;
  return deletedAt == null && activo !== false;
}

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

    const db = admin.firestore();

    const patientByEmail = await db.collection('patients').where('email', '==', email).limit(5).get();
    const hasActivePatient = patientByEmail.docs.some((doc) => isActiveUserDoc(doc.data()));
    if (hasActivePatient) {
      throw new HttpsError('already-exists', 'Este correo ya está en uso.');
    }

    const adminByEmail = await db.collection('admins').where('email', '==', email).limit(5).get();
    const hasActiveAdmin = adminByEmail.docs.some((doc) => isActiveUserDoc(doc.data()));
    if (hasActiveAdmin) {
      throw new HttpsError('already-exists', 'Este correo ya está en uso.');
    }

    // Si el correo quedó huérfano en Auth (sin doc en BD), se limpia para reutilizar.
    try {
      const existing = await admin.auth().getUserByEmail(email);
      const patientDoc = await db.collection('patients').doc(existing.uid).get();
      const adminDoc = await db.collection('admins').doc(existing.uid).get();
      if (patientDoc.exists || adminDoc.exists) {
        throw new HttpsError('already-exists', 'Este correo ya está en uso.');
      }
      await admin.auth().deleteUser(existing.uid);
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      if (e?.code !== 'auth/user-not-found') throw e;
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
        throw new HttpsError('already-exists', 'Este correo ya está en uso.');
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
