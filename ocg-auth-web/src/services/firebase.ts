import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { env, firebaseEnvStatus } from '../config/env';

if (!firebaseEnvStatus.ready) {
  throw new Error(
    `Firebase no configurado. Variables faltantes: ${firebaseEnvStatus.missing.join(', ')}. ` +
      'Configura .env.local con las claves VITE_FIREBASE_* y reinicia el servidor.',
  );
}

const firebaseConfig = {
  apiKey: env.firebaseApiKey,
  authDomain: env.firebaseAuthDomain,
  projectId: env.firebaseProjectId,
  storageBucket: env.firebaseStorageBucket,
  messagingSenderId: env.firebaseMessagingSenderId,
  appId: env.firebaseAppId,
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
