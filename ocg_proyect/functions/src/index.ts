import * as admin from 'firebase-admin';

import {loadSuperadminConfig} from './config/superadmins';

if (!admin.apps.length) {
  admin.initializeApp();
}

// Carga temprana de config (SUPERADMIN_UIDS / SUPERADMIN_EMAILS)
// para garantizar política fail-closed desde el arranque.
loadSuperadminConfig();

// Export de funciones del bloque BACKEND_ROLES se agregará en actividades posteriores.
