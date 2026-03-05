# BACKEND_ROLES — Cloud Functions

Este módulo implementa:
- `onAuthUserCreate` (1st gen): asigna claim `role=patient` y asegura `patients/{uid}`.
- `setAdminRole` (callable v2): promoción a admin con allowlist superadmin y fail-closed.
- `setFcmToken` (callable v2): actualiza token FCM por rol (`admins|patients`).

## 1) Prechecks

Desde `ocg_proyect/functions`:

```bash
npm ci
npm run build
```

Verifica versión de Node (runtime configurado en `functions/package.json`):

```bash
node -v
```

## 2) Configurar superadmins (obligatorio)

`setAdminRole` usa params y política fail-closed. Si no configuras allowlist, la función rechazará todo.

Configurar params en Firebase:

```bash
firebase functions:config:set \
  superadmin_uids="UID_SUPERADMIN_1,UID_SUPERADMIN_2" \
  superadmin_emails="admin1@dominio.com,admin2@dominio.com"
```

> Si usas entorno por proyecto, ejecuta con `--project <projectId>`.

## 3) Deploy

Desde `ocg_proyect`:

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Si prefieres por pasos:

```bash
cd functions && npm run deploy
cd .. && firebase deploy --only firestore:rules
cd .. && firebase deploy --only firestore:indexes
```

## 4) Verificación de claims (role)

### Caso A: usuario nuevo
1. Crear usuario en Auth (signup normal).
2. Confirmar que `onAuthUserCreate` corrió.
3. Verificar claim `role=patient`.

En cliente Flutter (debug):
```dart
final user = FirebaseAuth.instance.currentUser;
final token = await user?.getIdTokenResult(true); // force refresh
print(token?.claims?['role']); // expected: patient
```

### Caso B: promoción a admin
1. Invocar `setAdminRole` desde cuenta superadmin con `uid` objetivo.
2. Forzar refresh de token en cliente objetivo:
```dart
await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
```
3. Validar que claim ahora es `admin`.

## 5) Pruebas manuales mínimas

### Prueba 1 — Usuario nuevo
- Entrada: signup paciente.
- Esperado:
  - claim `patient` asignado.
  - documento `patients/{uid}` creado con campos mínimos.

### Prueba 2 — setAdminRole segura
- Entrada: caller NO allowlist.
- Esperado: `permission-denied`.
- Entrada: caller allowlist + uid válido.
- Esperado: claim `admin` y `admins/{uid}` con merge.

### Prueba 3 — setFcmToken por rol
- Entrada: usuario autenticado con role válido + token válido.
- Esperado: escritura en colección correcta por rol.
- Entrada: sin auth o rol inválido.
- Esperado: error controlado (`unauthenticated` / `permission-denied`).

## 6) Seguridad aplicada

- Fail-closed en `setAdminRole` cuando allowlist vacía/inválida.
- Bloqueo de auto-promoción de caller.
- Validación estricta de auth y role en callables.
- Sin logging de token FCM ni payload sensible.
