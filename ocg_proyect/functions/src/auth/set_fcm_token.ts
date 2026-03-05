import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

type SetFcmTokenData = {
  token?: string;
};

function getAuthContext(request: CallableRequest<SetFcmTokenData>): {
  uid: string;
  role: 'admin' | 'patient';
} {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  }

  const roleClaim = request.auth?.token?.role;
  if (roleClaim !== 'admin' && roleClaim !== 'patient') {
    throw new HttpsError('permission-denied', 'Rol inválido para actualizar FCM token.');
  }

  return {uid, role: roleClaim};
}

function normalizeToken(rawToken?: string): string {
  const token = (rawToken ?? '').trim();
  if (!token) {
    throw new HttpsError('invalid-argument', 'Token FCM requerido.');
  }

  if (token.length < 20 || token.length > 4096) {
    throw new HttpsError('invalid-argument', 'Token FCM inválido.');
  }

  return token;
}

export const setFcmToken = onCall<SetFcmTokenData>(async (request) => {
  const {uid, role} = getAuthContext(request);
  const token = normalizeToken(request.data?.token);

  const collection = role === 'admin' ? 'admins' : 'patients';

  await admin.firestore().collection(collection).doc(uid).set(
    {
      fcmToken: token,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    ok: true,
    uid,
    role,
    updated: true,
  };
});
