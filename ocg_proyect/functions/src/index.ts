import * as admin from 'firebase-admin';

import {onAuthUserCreate} from './auth/on_auth_user_create';
import {setAdminRole} from './auth/set_admin_role';
import {loadSuperadminConfig} from './config/superadmins';

if (!admin.apps.length) {
  admin.initializeApp();
}

// Carga temprana de config (SUPERADMIN_UIDS / SUPERADMIN_EMAILS)
// para garantizar política fail-closed desde el arranque.
loadSuperadminConfig();

export {onAuthUserCreate, setAdminRole};
