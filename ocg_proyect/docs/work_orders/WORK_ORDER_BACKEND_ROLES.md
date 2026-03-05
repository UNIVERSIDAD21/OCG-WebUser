# WORK_ORDER_BACKEND_ROLES.md

## BLOQUE ACTIVO

**BACKEND_ROLES (Cloud Functions)**

## Objetivo

Implementar backend seguro para roles y token FCM, alineado con `docs/specs/02_BASE_DE_DATOS.md` y `docs/specs/03_AUTENTICACION_Y_ROLES.md`.

## Alcance (sí se implementa)

1. Inicialización de `functions/` con TypeScript (Node 20/22).
2. Trigger Auth 1st gen: `onAuthUserCreate` (`functions.auth.user().onCreate`).
   - Asignar claim por defecto `role='patient'`.
   - Crear/asegurar `patients/{uid}` con campos mínimos seguros del esquema (sin `fotosUrls`).
3. Callable `setAdminRole` segura.
   - Solo superadmin allowlist (UID/email configurados) puede ejecutarla.
   - Asigna claim `role='admin'` al UID objetivo.
   - Asegura `admins/{uid}` con campos mínimos permitidos.
4. Callable `setFcmToken` segura.
   - Requiere auth.
   - Usa `request.auth.uid` + `request.auth.token.role`.
   - Escribe `fcmToken` en `admins/{uid}` o `patients/{uid}` según rol.
   - Idempotente y sin exponer PII en logs.
5. Versionar `firestore.rules` y `firestore.indexes.json` según doc 02 (sin abrir permisos).
6. `functions/README.md` con despliegue y pruebas.

## Fuera de alcance (no se toca)

- UI Flutter.
- Módulos de pacientes, agenda, tratamiento, pagos, simulador.
- Cambios de arquitectura no descritos en docs/specs.

## Reglas de seguridad no negociables

- Fail-closed: si allowlist de superadmin está vacía o inválida, `setAdminRole` rechaza todo.
- Paciente no puede auto-promoverse a admin.
- Todos los endpoints de rol requieren auth + validación estricta.
- No registrar tokens, payloads sensibles ni PII completa en logs.

## Restricciones de datos

- BD-01: prohibido `fotosUrls` en `patients/{uid}`.
- Respetar colecciones/subcolecciones del doc 02.
- Mantener compatibilidad con claims en reglas Firestore.

## Criterios de aceptación

- Funciones desplegables sin errores de tipo/build.
- Claims funcionando (`patient` por defecto y promoción `admin` controlada).
- `setFcmToken` escribe en colección correcta por rol.
- Rules/indexes versionados y alineados al doc 02.
