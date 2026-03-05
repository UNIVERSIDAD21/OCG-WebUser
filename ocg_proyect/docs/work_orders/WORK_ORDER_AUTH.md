# WORK_ORDER_AUTH.md

## BLOQUE ACTIVO

**Auth / Login / Router Guards / FCM Token update**

## Qué se implementa en este bloque

1. Login con email y contraseña.
2. Forgot password.
3. Logout con limpieza de estado.
4. Resolución de rol por Custom Claims (`admin` / `patient`) en cliente.
5. Guards de `go_router` por autenticación + rol.
6. Actualización de FCM token post-login de forma no bloqueante.

## Qué NO se toca todavía

- Registro de usuarios.
- Cloud Functions de roles (`on_user_created`, `set_admin_role`).
- Reglas de Firestore (`firestore.rules`).
- Índices de Firestore (`firestore.indexes.json`).
- Módulos de pacientes, agenda, tratamiento, pagos, simulador.

## Reglas de arquitectura

- Riverpod para estado.
- UI no accede directo a Firebase; usar servicios/providers existentes.
- Navegación centralizada en `go_router`.
- Manejo de errores visible para usuario.
- Mantener coherencia visual con tema OCG.

## Restricciones de Firebase (este bloque)

- Solo consumo de Firebase Auth y lectura de claims desde token.
- Si claims faltan o hay bloqueo por reglas/backend, se reporta como bloqueo.
- Cualquier ajuste backend se separa al bloque: `BACKEND_ROLES`.

## Definition of Done (resumido)

- Login funcional y estable.
- Forgot password funcional.
- Logout funcional.
- Guards por rol correctos sin acceso cruzado.
- Estrategia anti-race `authState` vs `userRole` aplicada.
- `updateFcmToken` no bloquea inicio de sesión.
