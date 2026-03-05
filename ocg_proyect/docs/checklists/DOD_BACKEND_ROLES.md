# DOD_BACKEND_ROLES.md

## Definition of Done — BACKEND_ROLES

- [ ] `functions/` inicializado con TypeScript y runtime Node 20/22.
- [ ] `onAuthUserCreate` implementado como Auth trigger 1st gen.
- [ ] `onAuthUserCreate` asigna claim `role='patient'`.
- [ ] `onAuthUserCreate` crea/asegura `patients/{uid}` sin `fotosUrls`.
- [ ] `setAdminRole` callable implementada con auth obligatoria.
- [ ] `setAdminRole` valida superadmin allowlist (UID/email).
- [ ] `setAdminRole` fail-closed cuando allowlist es vacía/inválida.
- [ ] `setAdminRole` asigna claim `role='admin'` al objetivo.
- [ ] `setAdminRole` asegura `admins/{uid}` con campos mínimos seguros.
- [ ] `setFcmToken` callable implementada y requiere auth.
- [ ] `setFcmToken` usa role claim para escribir `fcmToken` en `admins/` o `patients/`.
- [ ] `setFcmToken` es idempotente y no filtra PII en logs.
- [ ] `firestore.rules` versionado y alineado exactamente al doc 02.
- [ ] `firestore.indexes.json` versionado con los 7 índices del doc 02.
- [ ] `functions/src/index.ts` exporta todas las funciones del bloque.
- [ ] `functions/README.md` documenta deploy y pruebas.
- [ ] No se tocó UI en este bloque.
- [ ] Commit y push realizados como UNIVERSIDAD21 con mensaje en español.
