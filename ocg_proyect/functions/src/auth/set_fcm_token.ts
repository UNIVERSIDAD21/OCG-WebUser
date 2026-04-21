import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

export const setFcmToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User not authenticated');
  }

  const token = (request.data?.token || '').toString().trim();
  const deviceId = (request.data?.deviceId || '').toString().trim();
  const platform = (request.data?.platform || '').toString().trim() || 'android';
  if (!token) {
    throw new HttpsError('invalid-argument', 'Missing token');
  }
  if (!deviceId) {
    throw new HttpsError('invalid-argument', 'Missing deviceId');
  }

  const db = admin.firestore();
  const adminDoc = await db.collection('admins').doc(uid).get();
  const role = adminDoc.exists ? 'admin' : 'patient';

  const deviceRef = db
    .collection(role === 'admin' ? 'admins' : 'patients')
    .doc(uid)
    .collection('devices')
    .doc(deviceId);

  await deviceRef.set(
    {
      token,
      deviceId,
      platform,
      active: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db
    .collection(role === 'admin' ? 'admins' : 'patients')
    .doc(uid)
    .set(
      {
        fcmToken: token,
        fcmDeviceId: deviceId,
        fcmPlatform: platform,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  return { ok: true, role };
});

export const deleteFcmToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User not authenticated');
  }

  const deviceId = (request.data?.deviceId || '').toString().trim();
  if (!deviceId) {
    throw new HttpsError('invalid-argument', 'Missing deviceId');
  }

  const db = admin.firestore();
  const adminDoc = await db.collection('admins').doc(uid).get();
  const role = adminDoc.exists ? 'admin' : 'patient';
  const userRef = db.collection(role === 'admin' ? 'admins' : 'patients').doc(uid);

  await userRef.collection('devices').doc(deviceId).set(
    {
      active: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true, role };
});
