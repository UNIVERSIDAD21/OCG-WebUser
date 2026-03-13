import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

export const onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();

  // 1. Asignar claim de rol por defecto
  await admin.auth().setCustomUserClaims(user.uid, { role: 'patient' });

  // 2. Crear documento patients/{uid} con el esquema completo de PatientModel
  //    Los campos clínicos quedan en null/vacío — el admin los completa después
  await db.collection('patients').doc(user.uid).set(
    {
      id: user.uid,                    
      email: user.email ?? '',
      telefono: '',
      fechaNacimiento: null,
      fotoUrl: null,

      // Datos clínicos — vacíos hasta que el admin complete el perfil
      tipoTratamiento: null,
      etapaActual: null,
      fechaInicio: null,
      fechaEstimadaFin: null,
      notasClinicas: '',

      // Datos financieros
      totalTratamiento: 0,
      saldoPendiente: 0,
      fechaProximoPago: null,

      // Metadata
      fcmToken: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
});