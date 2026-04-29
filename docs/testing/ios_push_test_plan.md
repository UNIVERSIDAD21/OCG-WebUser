# iOS Push Test Plan

## Objetivo
Validar que Android siga funcionando y que iOS quede listo para push real cuando Apple/Firebase estén configurados.

## Resultado de validación técnica actual

| Prueba | Plataforma | Resultado | Evidencia | Observación |
| --------------------------- | ---------------- | -------------------- | -------------------------- | ----------- |
| `flutter pub get` | Flutter | FALLA | código 127 | `flutter` no está disponible en PATH del entorno actual |
| `flutter analyze` | Flutter | FALLA | código 127 | `flutter` no está disponible en PATH del entorno actual |
| `flutter test` | Flutter | FALLA | código 127 | `flutter` no está disponible en PATH del entorno actual |
| `flutter build apk --debug` | Android | FALLA | código 127 | `flutter` no está disponible en PATH del entorno actual |
| token FCM Android | Android | BLOQUEADO | sin prueba real | falta entorno Flutter/Android para validación directa |
| guardado token | Firestore | PARCIAL | revisión de código | existe estructura propuesta en proyecto, falta validación real contra backend |
| logout token | Flutter/Firebase | PARCIAL | revisión de código | existe método para inactivar tokens, falta prueba real |
| payload backend revisado | Functions | FALLA/PENDIENTE | revisión de commit | no hubo cambios backend en `4a98e1b` |
| payload iOS-ready | Functions | PENDIENTE | revisión técnica | falta cerrar payload y validarlo en backend |
| iOS build no-codesign | iOS | BLOQUEADO | `BLOCKED_NO_XCODE` | sin Mac/Xcode en este entorno |
| iPhone real | iOS | BLOQUEADO | pendiente externo | requiere Apple/APNs/iPhone |

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
