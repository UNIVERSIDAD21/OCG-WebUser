# iOS Push Test Plan

## Objetivo
Validar que Android siga funcionando y que iOS quede listo para push real cuando Apple/Firebase estén configurados.

## Casos Android
- [ ] Android sigue obteniendo token.
- [ ] Android recibe notificación con app abierta.
- [ ] Android recibe notificación en background.
- [ ] Android recibe notificación con app cerrada.
- [ ] Android navega correctamente al tocarla.

## Casos iOS
### Permisos
- [ ] La app pide permisos de alert.
- [ ] La app pide permisos de badge.
- [ ] La app pide permisos de sound.
- [ ] Se registra correctamente si queda `authorized`.
- [ ] Se registra correctamente si queda `denied`.
- [ ] Se registra correctamente si queda `provisional`.

### Token
- [ ] iOS obtiene token FCM.
- [ ] El token se guarda con `platform=ios`.
- [ ] El token refresh actualiza el documento.
- [ ] Logout marca el token como inactivo.

### Recepción
- [ ] App abierta: recibe y persiste historial.
- [ ] App en background: recibe y navega al tocar.
- [ ] App cerrada: `getInitialMessage()` reconstruye navegación.

### Casos funcionales
- [ ] Recordatorio de cita a paciente.
- [ ] Alerta administrativa.
- [ ] Pago registrado.
- [ ] Pago próximo.
- [ ] Tratamiento actualizado.
- [ ] Mensaje general.

### Navegación
- [ ] `appointment_created`
- [ ] `appointment_confirmed`
- [ ] `appointment_cancelled`
- [ ] `appointment_rescheduled`
- [ ] `appointment_reminder`
- [ ] `payment_registered`
- [ ] `payment_due`
- [ ] `treatment_updated`
- [ ] `general_message`

## Comprobaciones finales
- [ ] No se duplican tokens.
- [ ] No se duplican eventos de historial.
- [ ] Android no se rompió.
- [ ] iOS navega correctamente al tipo de pantalla esperado.
