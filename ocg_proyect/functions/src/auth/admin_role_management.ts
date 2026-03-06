import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {assertSuperadmin} from '../utils/authz';

type AddAdminRoleData = {
  email?: string;
};

type RemoveAdminRoleData = {
  email?: string;
  uid?: string;
};

function normalizeEmail(email?: string): string {
  const normalized = email?.trim().toLowerCase();
  if (!normalized) {
    throw new HttpsError('invalid-argument', "El campo 'email' es requerido.");
  }
  return normalized;
}

function normalizeUid(uid?: string): string {
  const normalized = uid?.trim();
  if (!normalized) {
    throw new HttpsError('invalid-argument', "El campo 'uid' es requerido.");
  }
  return normalized;
}

export const addAdminRole = onCall<AddAdminRoleData>({region: 'us-central1'}, async (request: CallableRequest<AddAdminRoleData>) => {
  assertSuperadmin(request);

  const auth = admin.auth();
  const db = admin.firestore();

  const email = normalizeEmail(request.data?.email);
  const assignedBy = request.auth?.token?.email ?? request.auth?.uid ?? 'unknown';

  let userRecord: admin.auth.UserRecord;
  let isNewUser = false;

  try {
    userRecord = await auth.getUserByEmail(email);
  } catch (err: unknown) {
    const authError = err as {code?: string};
    if (authError.code !== 'auth/user-not-found') {
      throw err;
    }

    isNewUser = true;
    userRecord = await auth.createUser({
      email,
      password: 'PasswordTemporalSerca2026*',
      emailVerified: true,
    });
  }

  const currentClaims = userRecord.customClaims ?? {};
  await auth.setCustomUserClaims(userRecord.uid, {
    ...currentClaims,
    role: 'admin',
    admin: true,
  });

  await db.collection('admin_users').doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      email,
      role: 'admin',
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      assignedBy,
    },
    {merge: true},
  );

  await db.collection('admins').doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      email,
      role: 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await db.collection('admin_logs').add({
    action: 'CREATE_OR_PROMOTE_ADMIN',
    targetEmail: email,
    targetUid: userRecord.uid,
    adminEmail: assignedBy,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: `Se otorgó rol de administrador a ${email}`,
  });

  return {
    ok: true,
    uid: userRecord.uid,
    email,
    role: 'admin',
    isNewUser,
    message: isNewUser
      ? `¡Éxito! Se creó una cuenta nueva para ${email} y se le asignó rol administrador.`
      : `¡Éxito! La cuenta existente de ${email} ahora tiene permisos de administrador.`,
  };
});

export const removeAdminRole = onCall<RemoveAdminRoleData>(
  {region: 'us-central1'},
  async (request: CallableRequest<RemoveAdminRoleData>) => {
    assertSuperadmin(request);

    const auth = admin.auth();
    const db = admin.firestore();

    const uid = normalizeUid(request.data?.uid);
    const email = normalizeEmail(request.data?.email);
    const assignedBy = request.auth?.token?.email ?? request.auth?.uid ?? 'unknown';

    const userRecord = await auth.getUser(uid);
    const currentClaims = userRecord.customClaims ?? {};

    await auth.setCustomUserClaims(uid, {
      ...currentClaims,
      role: 'patient',
      admin: false,
    });

    await db.collection('admin_users').doc(uid).delete();

    await db.collection('admins').doc(uid).set(
      {
        role: 'patient',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    await db.collection('admin_logs').add({
      action: 'REMOVE_ADMIN_ROLE',
      targetEmail: email,
      targetUid: uid,
      adminEmail: assignedBy,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: `Se removió el rol de administrador de ${email}`,
    });

    return {
      ok: true,
      uid,
      email,
      role: 'patient',
      message: `Permisos removidos exitosamente para ${email}.`,
    };
  },
);
