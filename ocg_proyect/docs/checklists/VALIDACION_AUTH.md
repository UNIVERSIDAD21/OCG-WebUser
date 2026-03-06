# VALIDACION_AUTH.md

## Matriz de validación obligatoria — Auth

> Regla: no avanzar al siguiente bloque sin cerrar esta matriz.

### A) Login
- [ ] Correo vacío -> muestra "Ingresa tu correo".
- [ ] Correo inválido -> muestra "Ingresa un correo válido".
- [ ] Contraseña vacía -> muestra "Ingresa tu contraseña".
- [ ] Credenciales incorrectas -> mensaje claro.
- [ ] Sin internet -> mensaje claro.
- [ ] Botón deshabilitado durante submit.
- [ ] Enter en contraseña dispara login.
- [ ] Tiempo de login aceptable (<3s en red normal).

### B) Registro de paciente (desde login)
- [ ] Nombre < 3 chars bloqueado.
- [ ] Email inválido bloqueado.
- [ ] Password < 6 bloqueada.
- [ ] Password sin letras+números bloqueada.
- [ ] Confirmación distinta bloqueada.
- [ ] Éxito muestra feedback y sesión iniciada.

### C) Forgot password
- [ ] Correo vacío/ inválido bloqueado.
- [ ] Envío exitoso muestra confirmación.
- [ ] user-not-found muestra mensaje entendible.
- [ ] network-request-failed muestra mensaje entendible.

### D) Logout
- [ ] Cierra sesión desde admin dashboard.
- [ ] Cierra sesión desde patient home.
- [ ] Botón deshabilitado mientras procesa.
- [ ] Estado auth/role invalidado al salir.

### E) Roles y guards
- [ ] Admin autenticado no entra a rutas patient.
- [ ] Patient autenticado no entra a rutas admin.
- [ ] Usuario no autenticado solo accede a login/forgot.
- [ ] Anti-race authState/userRole sin loops de navegación.

### F) FCM post-login
- [ ] update token se ejecuta sin bloquear login.
- [ ] Error de update token no rompe sesión.

### G) Evidencia mínima
- [ ] Capturas/registro de pruebas por cada sección A-F.
- [ ] Fecha, entorno (web/android), y resultado por caso.
