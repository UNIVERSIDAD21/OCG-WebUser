# PLAN_BACKEND_ROLES.md

## Alcance del plan

Plan de ejecución para **BACKEND_ROLES** (solo backend):
- Cloud Functions (TypeScript)
- Custom Claims (`role`)
- `firestore.rules`
- `firestore.indexes.json`
- `functions/README.md`
- Evidencias de prueba

Regla operativa de Git por actividad completada (obligatoria):
1. `git add -A`
2. `git commit -m "<mensaje en español>"`
3. `git push`
4. Reporte breve al usuario: qué se hizo, archivos tocados, verificación rápida.

---

## Día 1 — Bootstrap técnico y decisión de diseño

### Actividad 1
- **Objetivo:** Crear base de Cloud Functions en TypeScript con runtime Node 20/22 para despliegue moderno.
- **Archivos:** `functions/package.json`, `functions/tsconfig.json`, `functions/.gitignore`, `functions/src/index.ts`.
- **Evidencia Done:** `cd functions && npm run build` sin errores.
- **Riesgo+mitigación:** Config incompleta TS → validar build antes de commit.
- **Commit propuesto:** `inicializar cloud functions con typescript y runtime node 20`

### Actividad 2
- **Objetivo:** Definir dónde vive la allowlist de superadmins (UIDs) usando **Secrets/Params de Firebase Functions** como fuente principal, con fallback seguro y modo fail-closed.
- **Archivos:** `functions/src/config/superadmins.ts`, `functions/src/utils/authz.ts`, `functions/src/index.ts` (params/secrets wiring).
- **Evidencia Done:** prueba unitaria/manual de función que devuelva false con allowlist vacía o secreto ausente.
- **Riesgo+mitigación:** Secreto faltante en entorno → denegar toda promoción admin por defecto.
- **Commit propuesto:** `agregar allowlist de superadmin por secrets con política fail-closed`

### Actividad 3
- **Objetivo:** Documentar decisión A/B para `onAuthUserCreate` (crea/no crea patients doc).
- **Archivos:** `docs/work_orders/WORK_ORDER_BACKEND_ROLES.md`.
- **Evidencia Done:** sección “Decisión A/B” visible y justificada.
- **Riesgo+mitigación:** Elegir opción riesgosa → usar A por defecto si no hay evidencia sólida para B.
- **Commit propuesto:** `documentar decisión de diseño para alta de usuarios en backend_roles`

### Actividad 4
- **Objetivo:** Preparar checklist de control para ejecución diaria por actividad con commits obligatorios.
- **Archivos:** `docs/checklists/DOD_BACKEND_ROLES.md`.
- **Evidencia Done:** checklist contiene regla git por actividad y validaciones de seguridad.
- **Riesgo+mitigación:** Omisiones operativas → checklist explícito por actividad.
- **Commit propuesto:** `ajustar checklist backend_roles con control de commits por actividad`

---

## Día 2 — Roles y claims seguros

### Actividad 1
- **Objetivo:** Implementar `onAuthUserCreate` (1st gen) para asignar claim `role='patient'`.
- **Archivos:** `functions/src/auth/on_auth_user_create.ts`, `functions/src/index.ts`.
- **Evidencia Done:** build OK + función exportada en index.
- **Riesgo+mitigación:** Trigger incorrecto (2nd gen) → usar explícitamente `functions.auth.user().onCreate`.
- **Commit propuesto:** `implementar trigger onauthusercreate con claim patient por defecto`

### Actividad 2
- **Objetivo:** Aplicar decisión A/B en creación de documento `patients/{uid}` conforme spec y BD-01.
- **Archivos:** `functions/src/auth/on_auth_user_create.ts`.
- **Evidencia Done:** revisión de payload sin `fotosUrls`; validación con emulador/log.
- **Riesgo+mitigación:** Incompatibilidad de esquema → respetar campos mínimos seguros del doc 02.
- **Commit propuesto:** `alinear alta de paciente al esquema de base de datos sin fotosurls`

### Actividad 3
- **Objetivo:** Implementar callable `setAdminRole` con auth obligatoria, allowlist, deny auto-promoción e idempotencia.
- **Archivos:** `functions/src/auth/set_admin_role.ts`, `functions/src/index.ts`, `functions/src/utils/authz.ts`.
- **Evidencia Done:** caso no superadmin rechazado + caso admin existente retorna éxito idempotente.
- **Riesgo+mitigación:** Escalada de privilegios → validación estricta de caller + target.
- **Commit propuesto:** `implementar setadminrole seguro con validaciones estrictas`

### Actividad 4
- **Objetivo:** Asegurar creación de `admins/{uid}` con `merge: true` y documento mínimo (`email`, `fcmToken` vacío, `createdAt/updatedAt`) sin depender de datos inexistentes.
- **Archivos:** `functions/src/auth/set_admin_role.ts`.
- **Evidencia Done:** doc admin creado/mergeado con campos mínimos + timestamps; logs sanitizados.
- **Riesgo+mitigación:** Dependencia de campos no presentes → usar payload mínimo explícito y merge seguro.
- **Commit propuesto:** `asegurar documento admin mínimo con merge y sanitizar logs de roles`

---

## Día 3 — setFcmToken + reglas + índices

### Actividad 1
- **Objetivo:** Implementar callable `setFcmToken` autenticada y basada en claim role.
- **Archivos:** `functions/src/auth/set_fcm_token.ts`, `functions/src/index.ts`.
- **Evidencia Done:** build OK + callable exportada.
- **Riesgo+mitigación:** Escritura en colección incorrecta → switch explícito por role.
- **Commit propuesto:** `implementar callable setfcmtoken por rol con autenticación obligatoria`

### Actividad 2
- **Objetivo:** Validar formato/tamaño del token FCM e idempotencia de escritura.
- **Archivos:** `functions/src/auth/set_fcm_token.ts`.
- **Evidencia Done:** rechaza token inválido y acepta repetición sin efectos colaterales.
- **Riesgo+mitigación:** Abuso por payload inválido → validación fuerte y errores controlados.
- **Commit propuesto:** `agregar validación estricta e idempotencia en setfcmtoken`

### Actividad 3
- **Objetivo:** Versionar `firestore.rules` exacto al doc 02, sin abrir permisos (solo versionado en repo; despliegue documentado en Día 4).
- **Archivos:** `firestore.rules`.
- **Evidencia Done:** diff contra spec 02 revisado + validación de sintaxis en emulador sin error de parse.
- **Riesgo+mitigación:** Romper acceso esperado → copiar exacto spec y revisar helpers/paths antes de deploy.
- **Commit propuesto:** `versionar reglas de firestore según especificación oficial`

### Actividad 4
- **Objetivo:** Versionar `firestore.indexes.json` con los 7 índices del doc 02 (deploy se ejecuta y documenta en Día 4).
- **Archivos:** `firestore.indexes.json`.
- **Evidencia Done:** archivo contiene exactamente 7 índices esperados y estructura válida.
- **Riesgo+mitigación:** Falta de índice crítico → checklist de conteo exacto (7) previo a deploy.
- **Commit propuesto:** `agregar índices compuestos de firestore requeridos por especificación`

---

## Día 4 — README, pruebas y cierre operativo

### Actividad 1
- **Objetivo:** Documentar despliegue backend en `functions/README.md` (functions/rules/indexes).
- **Archivos:** `functions/README.md`.
- **Evidencia Done:** comandos de deploy y prechecks visibles y ejecutables.
- **Riesgo+mitigación:** Pasos incompletos → incluir comandos exactos copy/paste.
- **Commit propuesto:** `documentar despliegue de backend_roles en cloud functions y firestore`

### Actividad 2
- **Objetivo:** Documentar verificación de claims y refresh de token en cliente.
- **Archivos:** `functions/README.md`.
- **Evidencia Done:** sección específica con pasos para confirmar `role` actualizado.
- **Riesgo+mitigación:** Falso negativo por token cacheado → instruir refresh explícito.
- **Commit propuesto:** `documentar verificación de custom claims y refresco de token`

### Actividad 3
- **Objetivo:** Registrar plan de pruebas manuales mínimas (3 casos obligatorios).
- **Archivos:** `functions/README.md`, `docs/checklists/DOD_BACKEND_ROLES.md`.
- **Evidencia Done:** checklist marca casos: usuario nuevo/promo admin/setFcmToken por rol.
- **Riesgo+mitigación:** Pruebas ambiguas → definir entrada, acción y resultado esperado por caso.
- **Commit propuesto:** `añadir plan de pruebas manuales para backend_roles`

### Actividad 4
- **Objetivo:** Cierre documental del bloque con evidencia en logs y estado DoD.
- **Archivos:** `docs/logs/YYYY-MM-DD.md`, `docs/checklists/DOD_BACKEND_ROLES.md`, `docs/work_orders/WORK_ORDER_BACKEND_ROLES.md`.
- **Evidencia Done:** log actualizado con resultados finales y bloque marcado como cerrado.
- **Riesgo+mitigación:** Falta de trazabilidad → registrar evidencia de comandos y resultados.
- **Commit propuesto:** `cerrar bloque backend_roles con evidencias y checklist final`

---

## Día 5 (buffer opcional) — Hardening controlado

### Actividad 1
- **Objetivo:** Corregir hallazgos menores de seguridad detectados en pruebas sin ampliar scope.
- **Archivos:** `functions/src/**` (solo ajustes menores), `functions/README.md` si aplica.
- **Evidencia Done:** build OK + pruebas críticas continúan pasando.
- **Riesgo+mitigación:** Scope creep → solo fixes puntuales documentados.
- **Commit propuesto:** `aplicar ajustes menores de seguridad sin ampliar alcance`

### Actividad 2
- **Objetivo:** Revisar sanitización de logs en funciones de roles/token.
- **Archivos:** `functions/src/auth/*.ts`.
- **Evidencia Done:** ausencia de logs con token/email completo en revisión final.
- **Riesgo+mitigación:** Exposición de PII → máscara o supresión de datos sensibles.
- **Commit propuesto:** `reforzar sanitización de logs en funciones de backend_roles`

### Actividad 3
- **Objetivo:** Verificar consistencia final entre Work Order, Plan, DoD y README.
- **Archivos:** `docs/work_orders/*.md`, `docs/checklists/*.md`, `functions/README.md`.
- **Evidencia Done:** documentos alineados y sin contradicciones de scope.
- **Riesgo+mitigación:** Desalineación documental → checklist cruzado antes de cierre.
- **Commit propuesto:** `alinear documentación final del bloque backend_roles`

### Actividad 4
- **Objetivo:** Publicar reporte final consolidado del bloque para transición a AUTH_FRONTEND.
- **Archivos:** `docs/logs/YYYY-MM-DD.md`.
- **Evidencia Done:** reporte incluye qué se hizo, archivos tocados y cómo probar.
- **Riesgo+mitigación:** transferencia incompleta → formato fijo de reporte final.
- **Commit propuesto:** `publicar reporte final de backend_roles para transición a frontend`
