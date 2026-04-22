import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {logger} from 'firebase-functions';

function tokenPreview(token: string): string {
  if (token.length <= 18) return token;
  return `${token.slice(0, 10)}…${token.slice(-6)}`;
}

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

  const existingDeviceSnap = await deviceRef.get();

  await deviceRef.set(
    {
      token,
      deviceId,
      platform,
      active: true,
      deletedAt: null,
      invalidatedAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: existingDeviceSnap.exists
        ? (existingDeviceSnap.data()?.createdAt ?? admin.firestore.FieldValue.serverTimestamp())
        : admin.firestore.FieldValue.serverTimestamp(),
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

  logger.info('FCM token synchronized', {
    uid,
    role,
    deviceId,
    platform,
    tokenPreview: tokenPreview(token),
    callable: 'setFcmToken',
  });

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

  const remainingActive = await userRef
    .collection('devices')
    .where('active', '==', true)
    .limit(20)
    .get();

  const nextTopLevel = remainingActive.docs
    .map((doc) => doc.data())
    .sort((a, b) => {
      const aMillis = a.updatedAt?.toMillis?.() ?? 0;
      const bMillis = b.updatedAt?.toMillis?.() ?? 0;
      return bMillis - aMillis;
    })[0];
  await userRef.set(
    {
      fcmToken: nextTopLevel?.token ?? null,
      fcmDeviceId: nextTopLevel?.deviceId ?? null,
      fcmPlatform: nextTopLevel?.platform ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  logger.info('FCM token deactivated', {
    uid,
    role,
    deviceId,
    callable: 'deleteFcmToken',
    nextTopLevelDeviceId: nextTopLevel?.deviceId ?? null,
    nextTopLevelPlatform: nextTopLevel?.platform ?? null,
  });

  return { ok: true, role };
});
