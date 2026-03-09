# BLOQUE_07 — Pagos

> **Stack:** Flutter + Riverpod + Firestore + (futuro) PayU Colombia
> **Prioridad:** ALTA — Manejo de dinero real
> **Depende de:** Bloque 04 (pacientes) ✅

---

## Objetivo del bloque

Implementar el módulo completo de pagos: registro manual de pagos por el admin, historial de transacciones, visualización para el paciente, y preparación de la estructura para integración futura con PayU Colombia.

---

## Lo que debes entregar al cerrar este bloque

- [ ] `PaymentsRepository` completo (ya parcialmente especificado en docs/specs/02_BASE_DE_DATOS.md)
- [ ] `payments_provider` Riverpod reactivo
- [ ] Tab de Pagos en `PatientDetailScreen` (admin) funcional
- [ ] Tab de Pagos en la app del paciente funcional
- [ ] `RegisterPaymentDialog` para el admin
- [ ] `TransactionList` con historial de transacciones
- [ ] `PaymentSummaryCard` con resumen financiero
- [ ] Estructura base para PayU (sin integración real aún — solo placeholders documentados)
- [ ] `flutter analyze` ✅ y `flutter test` ✅

---

## Regla crítica DAT-01 — No olvidar jamás

El `saldoPendiente` en `patients/{id}` es **solo un cache** para la lista de pacientes.

La **fuente de verdad** es `payments/{patientId}.saldoPendiente`.

Toda operación de pago debe:
1. Actualizar `payments/{patientId}` (fuente de verdad)
2. Actualizar `patients/{patientId}` (cache)
3. Hacerlo en un **batch atómico** — nunca por separado

---

## Archivos a crear / completar

### 1. `lib/features/payments/data/models/payment_model.dart`

Ya existe la especificación. Implementar con:

```dart
class PaymentModel {
  final String id;               // = patientId (BD-03)
  final String patientId;
  final double totalTratamiento;
  final double montoPagado;
  final double saldoPendiente;   // FUENTE DE VERDAD
  final DateTime? fechaProximoPago;
  final PaymentStatus estado;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PaymentTransaction {
  final String id;
  final double monto;
  final DateTime fecha;
  final PaymentMethod metodo;
  final String? referencia;
  final String registradoPor;    // adminId o 'payu_webhook'
  final String? notas;
  final String? reciboUrl;       // Storage URL del PDF (futuro)
}

enum PaymentStatus { alDia, pendiente, vencido, pagadoTotal }

enum PaymentMethod { efectivo, transferencia, tarjeta, payu }
```

---

### 2. `lib/features/payments/data/repositories/payments_repository.dart`

```dart
class PaymentsRepository {
  final FirebaseFirestore _db;

  // Stream del documento de pagos (acceso directo — BD-03)
  Stream<PaymentModel?> watchPatientPayments(String patientId);

  // Stream de transacciones ordenadas por fecha desc
  Stream<List<PaymentTransaction>> watchTransactions(String patientId);

  // Registrar pago manual (admin)
  // DAT-01: batch atómico payments/ + patients/
  Future<void> registerManualPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  });

  // Inicializar documento de pagos al crear un paciente (si no existe)
  Future<void> initializePaymentDocument({
    required String patientId,
    required double totalTratamiento,
  });

  // Actualizar fecha del próximo pago
  Future<void> updateNextPaymentDate(String patientId, DateTime fecha);
}
```

**En `registerManualPayment`:**
```dart
final batch = _db.batch();

// Crear transacción en subcolección
final txRef = _db.collection(FirestorePaths.transactions(patientId)).doc();
batch.set(txRef, PaymentTransaction(...).toJson());

// Actualizar payments/ (FUENTE DE VERDAD)
batch.update(_db.collection('payments').doc(patientId), {
  'montoPagado': FieldValue.increment(monto),
  'saldoPendiente': FieldValue.increment(-monto),
  'estado': _calculateStatus(...),  // Recalcular estado
  'updatedAt': FieldValue.serverTimestamp(),
});

// Actualizar patients/ (CACHE)
batch.update(_db.collection('patients').doc(patientId), {
  'saldoPendiente': FieldValue.increment(-monto),
  'updatedAt': FieldValue.serverTimestamp(),
});

await batch.commit();
```

---

### 3. `lib/features/payments/providers/payments_provider.dart`

```dart
final paymentsRepositoryProvider = Provider<PaymentsRepository>(...);

// Stream del resumen de pagos de un paciente
final patientPaymentProvider = StreamProvider.family<PaymentModel?, String>(
  (ref, patientId) => ref.watch(paymentsRepositoryProvider).watchPatientPayments(patientId),
);

// Stream de transacciones de un paciente
final patientTransactionsProvider = StreamProvider.family<List<PaymentTransaction>, String>(
  (ref, patientId) => ref.watch(paymentsRepositoryProvider).watchTransactions(patientId),
);

// Notifier para registrar pago
class RegisterPaymentNotifier extends AutoDisposeAsyncNotifier<void> {
  Future<void> register({...});
}
final registerPaymentProvider = AutoDisposeAsyncNotifierProvider<RegisterPaymentNotifier, void>(...);
```

---

### 4. `lib/features/payments/presentation/widgets/payment_summary_card.dart`

Card de resumen financiero que muestra:

```
┌──────────────────────────────────┐
│  Resumen financiero              │
│                                  │
│  Total tratamiento   $1.500.000  │
│  Pagado              $  800.000  │
│  Saldo pendiente     $  700.000  │ ← en bronze si > 0, en success si = 0
│                                  │
│  Próximo pago: 15 Mar 2026       │
│  Estado: Al día ✓                │
└──────────────────────────────────┘
```

- Usar `OcgCard` como contenedor base
- Formato de moneda en COP: `NumberFormat.currency(locale: 'es_CO', symbol: '\$')`
- El estado usa `OcgChip` con colores semánticos: `alDia` → verde, `pendiente` → naranja, `vencido` → rojo, `pagadoTotal` → azul/success

---

### 5. `lib/features/payments/presentation/widgets/transaction_list.dart`

Lista de transacciones. Cada ítem:

```
Transferencia bancaria           $300.000
Ref: 2024-TRF-001               15 Mar 2026
Registrado por: admin@ocg.co    [Notas si existen]
```

- Ordenada por fecha desc (más reciente primero)
- Si lista vacía: `OcgEmptyState` con "Sin pagos registrados"
- Usar `ListView.separated` con `Divider` sutil entre ítems

---

### 6. `lib/features/payments/presentation/widgets/register_payment_dialog.dart`

Dialog para que el admin registre un pago manual.

**Campos:**
1. Monto (obligatorio, numérico, > 0, no puede superar el saldo pendiente)
2. Método de pago: Dropdown con `PaymentMethod` (efectivo, transferencia, tarjeta)
3. Referencia: TextField opcional (máx 100 chars)
4. Notas: TextField opcional multilínea

**Validaciones:**
- Monto obligatorio y positivo
- Monto no puede exceder el saldo pendiente actual
- Si monto == saldo pendiente: mostrar badge "Este pago saldará la deuda completa"

**Acciones:**
- "Registrar pago" → llama a `registerPaymentProvider`
- "Cancelar" → cierra el dialog

---

### 7. Llenar `patient_payments_tab.dart` (admin)

```dart
// lib/features/patients/presentation/tabs/patient_payments_tab.dart

Column(
  children: [
    PaymentSummaryCard(patientId: patientId),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      icon: Icon(Icons.add),
      label: Text('Registrar pago'),
      onPressed: () => showDialog(RegisterPaymentDialog(patientId: patientId)),
    ),
    const SizedBox(height: 16),
    TransactionList(patientId: patientId),
  ],
)
```

---

### 8. Pantalla de pagos para el paciente

En `PatientAppointmentsScreen` ya existe la ruta. Crear o actualizar la pantalla de pagos del paciente:

```dart
// lib/features/payments/presentation/patient_payments_screen.dart

Scaffold con:
  - PaymentSummaryCard (solo lectura, sin botón de registrar)
  - TransactionList (solo sus transacciones)
  - Sección "Próximo pago" con la fecha si existe
  - [PLACEHOLDER] Botón "Pagar con PayU" deshabilitado con tooltip "Próximamente"
```

---

## Estructura para PayU (sin integración real aún)

Crear el archivo vacío documentado:

```dart
// lib/services/api/payu_service.dart

/// PayU Colombia — integración futura
/// 
/// Documentación: https://developers.payU.com/colombia
/// Ambiente sandbox: sandbox.api.payulatam.com
/// 
/// Flujo esperado:
/// 1. Admin o paciente inicia pago desde la app
/// 2. Se crea una sesión de pago en Cloud Functions (evitar exponer API keys en cliente)
/// 3. Cloud Function genera el formulario/redirect de PayU
/// 4. PayU notifica el resultado via webhook a Cloud Function
/// 5. Cloud Function llama a PaymentsRepository.registerWebhookPayment(...)
/// 6. PaymentsRepository ejecuta batch DAT-01 (payments/ + patients/)
/// 
/// NOTA: No implementar hasta que la doctora tenga cuenta PayU Colombia activa.

class PayuService {
  // TODO: Implementar en Bloque de Integración PayU
}
```

---

## Criterios de cierre del bloque

- [ ] Admin puede registrar pagos manuales desde el tab del paciente
- [ ] El saldo pendiente se actualiza en tiempo real (stream reactivo)
- [ ] El historial de transacciones es visible y ordenado
- [ ] El paciente ve su resumen financiero en su pantalla de pagos
- [ ] `PaymentSummaryCard` muestra formato correcto en COP
- [ ] Batch atómico: payments/ y patients/ se actualizan juntos (DAT-01)
- [ ] Validación: monto positivo, no supera saldo pendiente
- [ ] `PayuService` vacío con documentación del flujo futuro
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ (serialización PaymentModel, cálculo de estado, validaciones del dialog)

---

## Orden recomendado de ejecución

1. `PaymentModel` + `PaymentTransaction` con serialización + tests
2. `PaymentsRepository` (watchPayments, watchTransactions, registerManualPayment)
3. `payments_provider` Riverpod
4. `PaymentSummaryCard` widget
5. `TransactionList` widget
6. `RegisterPaymentDialog`
7. Llenar `patient_payments_tab.dart`
8. `PatientPaymentsScreen` para el paciente
9. `PayuService` stub documentado
10. Validación manual + analyze + tests
