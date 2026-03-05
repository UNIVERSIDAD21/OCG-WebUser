import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {assertSuperadmin} from '../utils/authz';

type SetAdminRoleData = {
  uid?: string;
};

function getTargetUid(request: CallableRequest<SetAdminRoleData>): string {
  const uid = request.data?.uid?.trim();
  if (!uid) {
    throw new HttpsError('invalid-argument', 'Debes enviar uid objetivo.');
  }
  return uid;
}

export const setAdminRole = onCall<SetAdminRoleData>(async (request) => {
  assertSuperadmin(request);

  const callerUid = request.auth?.uid;
  const targetUid = getTargetUid(request);

  if (callerUid === targetUid) {
    throw new HttpsError('permission-denied', 'No puedes auto-promoverte a admin.');
  }

  const auth = admin.auth();
  const db = admin.firestore();

  const userRecord = await auth.getUser(targetUid);
  const currentClaims = userRecord.customClaims ?? {};
  const alreadyAdmin = currentClaims.role === 'admin';

  if (!alreadyAdmin) {
    await auth.setCustomUserClaims(targetUid, {
      ...currentClaims,
      role: 'admin',
    });
  }

  await db.collection('admins').doc(targetUid).set(
    {
      uid: targetUid,
      email: userRecord.email ?? null,
      role: 'admin',
      fcmToken: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    ok: true,
    uid: targetUid,
    role: 'admin',
    idempotent: alreadyAdmin,
  };
});
