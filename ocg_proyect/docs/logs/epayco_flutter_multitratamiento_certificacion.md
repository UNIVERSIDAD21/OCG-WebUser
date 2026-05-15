# Certificación Flutter PayU multi-tratamiento

Fecha: 2026-05-04

## Confirmación principal

En Flutter, PayU ahora exige `treatmentId` en todos los flujos funcionales de inicio de pago.
No queda ningún flujo PayU funcional que pueda iniciar `createPayuSession` sin `treatmentId`.

## Archivos auditados

- `lib/features/payments/services/payu_service.dart`
- `lib/features/payments/providers/payments_provider.dart`
- `lib/features/payments/presentation/patient_payments_screen.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/app/router/app_router.dart`
- `lib/app/router/route_names.dart`
- `lib/services/api/payu_service.dart`
- `test/features/payments/payu_service_test.dart`
- `test/features/payments/payu_provider_test.dart`
- `test/features/payments/patient_payments_screen_payu_test.dart`

## Resultado de la auditoría anti-regresión

### Rutas correctas y activas

- `PatientPaymentsScreen` (vista paciente treatment-aware):
  - el botón PayU usa el tratamiento seleccionado;
  - el diálogo de confirmación menciona el tratamiento seleccionado;
  - si la cuenta del tratamiento no existe, el botón queda deshabilitado.
- `InitiatePayuPaymentNotifier`:
  - valida `treatmentId`, `saldoPendiente` y `monto` antes de llamar backend.
- `PayuService.createPaymentSession`:
  - vuelve a validar `treatmentId`, `saldoPendiente`, `monto` y exige `checkoutUrl`.

### Rutas legacy / no operativas

- `lib/services/api/payu_service.dart` quedó marcado como `@Deprecated` y no participa en el flujo activo.
- La vista admin en `PatientPaymentsScreen` no expone PayU global; solo conserva registro manual de pagos.

### Limpieza técnica aplicada

- Se eliminaron rutas ambiguas donde el código podía sugerir `_confirmAndPayu(..., '', ...)`.
- El código expresa de forma explícita que PayU solo funciona por tratamiento.

## Pruebas agregadas/ajustadas

### `payu_service_test.dart`
- envía `patientId`, `treatmentId`, `monto`, `patientEmail`, `patientName`;
- retorna `checkoutUrl`;
- falla si `treatmentId` está vacío;
- falla si `monto <= 0`;
- falla si `saldoPendiente` es `null` o `<= 0`;
- falla si `monto > saldoPendiente`;
- falla si backend no devuelve `checkoutUrl`.

### `payu_provider_test.dart`
- no llama a `PayuService` si `treatmentId` está vacío;
- no llama a `PayuService` si `saldoPendiente <= 0`;
- no llama a `PayuService` si `monto > saldoPendiente`;
- llama a `PayuService` con el `treatmentId` correcto cuando todo es válido;
- el provider queda en `AsyncError` cuando falla validación.

### `patient_payments_screen_payu_test.dart`
- paciente con dos tratamientos;
- seleccionar A usa A;
- cambiar a B usa B;
- no aparece flujo global de “pagar saldo total del paciente”.

## Comandos ejecutados

- `flutter analyze`
- `flutter test test/features/payments/payu_service_test.dart`
- `flutter test test/features/payments/payu_provider_test.dart test/features/payments/patient_payments_screen_payu_test.dart`
- `flutter test test/features/payments/`

## Resultado de validación

- `flutter analyze`: OK
- `flutter test test/features/payments/payu_service_test.dart`: OK
- `flutter test` de pruebas nuevas PayU/provider/widget: OK
- `flutter test test/features/payments/`: no quedó 100% verde por un fallo ajeno a PayU en `treatment_financial_repository_test.dart`

## Pendiente por intervención humana

- configurar keys PayU;
- probar transacción real o sandbox;
- validar webhook con PayU externo.

No se hizo despliegue, no se tocaron credenciales y no se usó Firebase real.
