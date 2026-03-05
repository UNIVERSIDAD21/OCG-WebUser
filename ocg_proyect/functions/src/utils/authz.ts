import {CallableRequest, HttpsError} from 'firebase-functions/v2/https';

import {loadSuperadminConfig} from '../config/superadmins';

type AuthData = {
  uid: string;
  email?: string;
};

function getAuthData(request: CallableRequest<unknown>): AuthData {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  }

  const email = request.auth?.token?.email;
  return {uid, email: typeof email === 'string' ? email : undefined};
}

export function isSuperadmin(uid: string, email?: string): boolean {
  const cfg = loadSuperadminConfig();

  // Fail-closed: si la allowlist está vacía/inválida, nadie es superadmin.
  if (!cfg.enabled) return false;

  if (cfg.uids.has(uid.toLowerCase())) return true;
  if (email && cfg.emails.has(email.toLowerCase())) return true;

  return false;
}

export function assertSuperadmin(request: CallableRequest<unknown>): void {
  const auth = getAuthData(request);
  if (!isSuperadmin(auth.uid, auth.email)) {
    throw new HttpsError('permission-denied', 'No autorizado para promover administradores.');
  }
}
