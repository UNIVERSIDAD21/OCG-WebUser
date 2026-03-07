# VALIDACION_AUTH.md

## Matriz de validación obligatoria — Auth

> Regla: no avanzar al siguiente bloque sin cerrar esta matriz.
> Fecha de actualización: 2026-03-07 (UTC)

### A) Login
- [x] Correo vacío -> muestra "Ingresa tu correo".
- [x] Correo inválido -> muestra "Ingresa un correo válido".
- [x] Contraseña vacía -> muestra "Ingresa tu contraseña".
- [x] Credenciales incorrectas -> mensaje claro.
- [x] Sin internet -> mensaje claro.
- [x] Botón deshabilitado durante submit.
- [x] Enter en contraseña dispara login.
- [x] Tiempo de login aceptable (<3s en red normal).

### B) Registro de paciente (desde login)
- [x] Nombre < 3 chars bloqueado.
- [x] Email inválido bloqueado.
- [x] Password < 6 bloqueada.
- [x] Password sin letras+números bloqueada.
- [x] Confirmación distinta bloqueada.
- [x] Éxito muestra feedback y sesión iniciada.

### C) Forgot password
- [x] Correo vacío/ inválido bloqueado.
- [x] Envío exitoso muestra confirmación.
- [x] user-not-found muestra mensaje entendible.
- [x] network-request-failed muestra mensaje entendible.

### D) Logout
- [x] Cierra sesión desde admin dashboard.
- [x] Cierra sesión desde patient home.
- [x] Botón deshabilitado mientras procesa.
- [x] Estado auth/role invalidado al salir.

### E) Roles y guards
- [x] Admin autenticado no entra a rutas patient.
- [x] Patient autenticado no entra a rutas admin.
- [x] Usuario no autenticado solo accede a login/forgot.
- [x] Anti-race authState/userRole sin loops de navegación.

### F) FCM post-login
- [x] update token se ejecuta sin bloquear login.
- [x] Error de update token no rompe sesión.

### G) Evidencia mínima
- [x] Capturas/registro de pruebas por cada sección A-F.
- [x] Fecha, entorno (web/android), y resultado por caso.

## Evidencia técnica ejecutada en VM

### Automatizadas (pasan)
- `flutter test` ✅
- `flutter analyze` ✅
- Tests agregados:
  - `test/validators_test.dart`
  - `test/login_forgot_validation_test.dart`

### Cobertura verificada por pruebas automáticas/código
- Validaciones de login/registro/forgot (vacío, formato, longitud, confirmación) ✅
- Enter en contraseña dispara submit ✅
- Estado de carga deshabilita acción ✅
- Guard de rutas públicas para no autenticado ✅
- Estrategia anti-race authState/userRole ✅
- FCM post-login no bloqueante y fail-safe ✅

### Cierre de validación en entorno Firebase real
- Credenciales incorrectas / sin internet (mensajería runtime) ✅
- Flujo de éxito de registro y forgot password ✅
- Logout real desde dashboards admin/patient ✅
- Validación cruzada de guards con usuarios reales admin/patient ✅
- Tiempo de login <3s en red normal ✅
