# Auditoría Flutter ↔ PayU multi-tratamiento

Fecha: 2026-05-04

## Rutas Flutter auditadas

Se revisaron estas entradas y referencias de PayU:

- `lib/features/payments/services/payu_service.dart`
- `lib/features/payments/providers/payments_provider.dart`
- `lib/features/payments/presentation/patient_payments_screen.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/app/router/app_router.dart`
- `lib/app/router/route_names.dart`
- `lib/services/api/payu_service.dart` (stub legacy, marcado como deprecated/no usar)

Búsquedas usadas:
- `createPaymentSession`
- `initiatePayuPaymentProvider`
- `_confirmAndPayu`
- `PayuService`
- `patientPayuCheckout`
- `Pagar con PayU`
- `payu`

## Flujos PayU existentes

### Flujo activo de paciente

1. `PatientPaymentsScreen` muestra cuentas por tratamiento.
2. El usuario selecciona un tratamiento.
3. El botón PayU usa el tratamiento seleccionado.
4. `InitiatePayuPaymentNotifier` valida `treatmentId`, `saldoPendiente` y `monto`.
5. `PayuService.createPaymentSession` vuelve a validar y envía `treatmentId` al callable `createPayuSession`.
6. Si llega `checkoutUrl`, navega a `patientPayuCheckout`.

### Flujo admin

- En admin **no existe** botón PayU operativo.
- Admin solo conserva registro manual de pagos por cuenta/tratamiento.
- Se retiraron rutas internas heredadas que podían dejar un `_confirmAndPayu(..., '')` aunque no fueran alcanzables funcionalmente.

## Confirmación de seguridad funcional

- El flujo activo de PayU en Flutter ahora **siempre requiere `treatmentId`**.
- `PayuService.createPaymentSession` falla localmente si `treatmentId` está vacío.
- `InitiatePayuPaymentNotifier` falla localmente si `treatmentId` está vacío.
- La UI del paciente deshabilita PayU si la cuenta del tratamiento aún no existe.
- No queda botón global de “pagar saldo total del paciente” sin tratamiento asociado dentro del flujo PayU.

## Pruebas ejecutadas

- `flutter analyze`
- `flutter test test/features/payments/payu_service_test.dart`
- `flutter test test/features/payments/`

## Pendiente solo por intervención humana

- Configurar credenciales/keys reales de PayU según ambiente.
- Probar una transacción real o sandbox end-to-end con cuenta PayU válida.

No se hizo despliegue ni se tocaron credenciales en esta orden.
