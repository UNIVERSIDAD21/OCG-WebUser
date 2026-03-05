# DOD_AUTH.md

## Definition of Done — Módulo Auth

- [ ] Login email/password funcional en web y app.
- [ ] Forgot password funcional con feedback claro.
- [ ] Logout funcional con limpieza de estado.
- [ ] Rol leído desde Custom Claims en cliente.
- [ ] Guards `go_router` aplican acceso por auth y rol.
- [ ] No hay acceso cruzado admin/patient por rutas.
- [ ] Estrategia anti-race `authState` vs `userRole` implementada.
- [ ] `updateFcmToken` se ejecuta post-login y es no bloqueante.
- [ ] Errores de login/reset visibles y comprensibles para usuario.
- [ ] Si hay bloqueo por backend (claims/reglas), queda documentado para `BACKEND_ROLES`.
