import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

export const onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();

  await admin.auth().setCustomUserClaims(user.uid, {role: 'patient'});

  await db.collection('patients').doc(user.uid).set(
    {
      uid: user.uid,
      email: user.email ?? null,
      displayName: user.displayName ?? null,
      role: 'patient',
      fcmToken: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
});
