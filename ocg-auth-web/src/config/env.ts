const requiredEnv = [
  'VITE_FIREBASE_API_KEY',
  'VITE_FIREBASE_AUTH_DOMAIN',
  'VITE_FIREBASE_PROJECT_ID',
  'VITE_FIREBASE_STORAGE_BUCKET',
  'VITE_FIREBASE_MESSAGING_SENDER_ID',
  'VITE_FIREBASE_APP_ID',
] as const;

type EnvKey = (typeof requiredEnv)[number];

const missingEnv = requiredEnv.filter((key) => !import.meta.env[key]);

if (missingEnv.length > 0) {
  console.warn(
    `[OCG-WebUser] Faltan variables Firebase: ${missingEnv.join(', ')}. ` +
      'Copia .env.example a .env.local y completa valores para habilitar autenticación.',
  );
}

const readEnv = (key: EnvKey) => import.meta.env[key] as string;

export const env = {
  firebaseApiKey: readEnv('VITE_FIREBASE_API_KEY'),
  firebaseAuthDomain: readEnv('VITE_FIREBASE_AUTH_DOMAIN'),
  firebaseProjectId: readEnv('VITE_FIREBASE_PROJECT_ID'),
  firebaseStorageBucket: readEnv('VITE_FIREBASE_STORAGE_BUCKET'),
  firebaseMessagingSenderId: readEnv('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  firebaseAppId: readEnv('VITE_FIREBASE_APP_ID'),
};

export const firebaseEnvStatus = {
  ready: missingEnv.length === 0,
  missing: missingEnv,
};
