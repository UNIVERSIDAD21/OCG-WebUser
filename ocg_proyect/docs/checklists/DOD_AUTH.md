# DOD_AUTH.md

## Definition of Done — Módulo Auth

- [x] Login email/password funcional en web y app.
- [x] Forgot password funcional con feedback claro.
- [x] Logout funcional con limpieza de estado.
- [x] Rol leído desde Custom Claims en cliente.
- [x] Guards `go_router` aplican acceso por auth y rol.
- [x] No hay acceso cruzado admin/patient por rutas.
- [x] Estrategia anti-race `authState` vs `userRole` implementada.
- [x] `updateFcmToken` se ejecuta post-login y es no bloqueante.
- [x] Errores de login/reset visibles y comprensibles para usuario.
- [x] Sin bloqueo backend activo para avance de Auth; `BACKEND_ROLES` queda como bloque separado.
