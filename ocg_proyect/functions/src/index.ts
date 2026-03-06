import * as admin from 'firebase-admin';

import {onAuthUserCreate} from './auth/on_auth_user_create';
import {addAdminRole, removeAdminRole} from './auth/admin_role_management';
import {setAdminRole} from './auth/set_admin_role';
import {setFcmToken} from './auth/set_fcm_token';

if (!admin.apps.length) {
  admin.initializeApp();
}

export {onAuthUserCreate, setAdminRole, addAdminRole, removeAdminRole, setFcmToken};
