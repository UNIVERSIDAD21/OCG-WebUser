# DOD_BACKEND_ROLES.md

## Definition of Done — BACKEND_ROLES

- [x] `functions/` inicializado con TypeScript y runtime Node 20/22.
- [x] `onAuthUserCreate` implementado como Auth trigger 1st gen.
- [x] `onAuthUserCreate` asigna claim `role='patient'`.
- [x] `onAuthUserCreate` crea/asegura `patients/{uid}` sin `fotosUrls`.
- [x] `setAdminRole` callable implementada con auth obligatoria.
- [x] `setAdminRole` valida superadmin allowlist (UID/email).
- [x] `setAdminRole` fail-closed cuando allowlist es vacía/inválida.
- [x] `setAdminRole` asigna claim `role='admin'` al objetivo.
- [x] `setAdminRole` asegura `admins/{uid}` con campos mínimos seguros.
- [x] `setFcmToken` callable implementada y requiere auth.
- [x] `setFcmToken` usa role claim para escribir `fcmToken` en `admins/` o `patients/`.
- [x] `setFcmToken` es idempotente y no filtra PII en logs.
- [x] `firestore.rules` versionado y alineado exactamente al doc 02.
- [x] `firestore.indexes.json` versionado con los 7 índices del doc 02.
- [x] `functions/src/index.ts` exporta todas las funciones del bloque.
- [x] `functions/README.md` documenta deploy y pruebas.
- [x] No se tocó UI en este bloque.
- [x] Commit y push realizados como UNIVERSIDAD21 con mensaje en español.
