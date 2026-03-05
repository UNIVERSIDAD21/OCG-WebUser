import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

// Export de funciones del bloque BACKEND_ROLES se agregará en actividades posteriores.
