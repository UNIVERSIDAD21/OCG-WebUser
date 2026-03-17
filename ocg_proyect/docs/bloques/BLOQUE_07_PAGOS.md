# BLOQUE_07 — Módulo de Pagos Completo

> **Stack:** Flutter + Riverpod + Firestore + Cloud Functions (TypeScript) + PayU Colombia
> **Prioridad:** ALTA — Manejo de dinero real
> **Depende de:** Bloque 04 (pacientes) ✅ · Bloque 05 (citas) ✅
> **Versión:** 2.0 — Incluye integración PayU Colombia completa con sandbox

---

## Contexto de negocio

Este módulo maneja el dinero real de la clínica. Cada peso debe quedar registrado correctamente.
El sistema soporta dos orígenes de pago:

1. **Pagos manuales** — el admin registra lo que el paciente pagó en efectivo o transferencia.
2. **Pagos en línea vía PayU** — el paciente paga con tarjeta, PSE o Efecty desde la app.

Ambos flujos terminan en el mismo lugar: una transacción en Firestore y el saldo actualizado.
La diferencia es quién inicia el pago y cómo llega la confirmación al servidor.

---

## Regla crítica DAT-01 — Leer antes de tocar cualquier archivo de pagos

El campo `saldoPendiente` existe en **dos colecciones**. No son iguales.

| Colección | Rol | Cuándo usarlo |
|-----------|-----|---------------|
| `payments/{patientId}.saldoPendiente` | **FUENTE DE VERDAD** | Siempre, para cálculos y lógica |
| `patients/{patientId}.saldoPendiente` | **CACHE** | Solo para mostrar en listas rápidas |

**Regla de oro:** Toda escritura de pago actualiza primero `payments/` y luego `patients/`
en un **batch atómico**. Si el batch falla, ninguno se actualiza. Nunca por separado.

---

## Lo que se entrega al cerrar este bloque

- [ ] `PaymentModel` + `PaymentTransaction` con serialización completa y tests unitarios
- [ ] `PaymentsRepository` con todos los métodos (manual + PayU + inicialización)
- [ ] `payments_provider` Riverpod reactivo
- [ ] `PaymentSummaryCard` widget con formato COP
- [ ] `TransactionList` widget con historial ordenado
- [ ] `RegisterPaymentDialog` para el admin (efectivo / transferencia)
- [ ] `patient_payments_tab.dart` completo (vista admin dentro del detalle de paciente)
- [ ] `PatientPaymentsScreen` completo (vista del paciente en su app)
- [ ] `PdfReceiptService` — genera recibo PDF y lo sube a Firebase Storage
- [ ] Cloud Function `createPayuSession` — genera sesión de pago PayU
- [ ] Cloud Function `payuWebhook` — recibe confirmación de PayU, verifica firma MD5
- [ ] `PayuService` en Flutter — llama a `createPayuSession` y abre WebView
- [ ] Reglas Firestore actualizadas para la colección `payments/`
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅

---

## Estructura de archivos a crear

```
lib/
└── features/
    └── payments/
        ├── data/
        │   ├── models/
        │   │   └── payment_model.dart          ← PaymentModel + PaymentTransaction + enums
        │   └── repositories/
        │       └── payments_repository.dart    ← toda la lógica de Firestore
        ├── providers/
        │   └── payments_provider.dart          ← Riverpod providers
        ├── presentation/
        │   ├── patient_payments_screen.dart    ← pantalla del paciente
        │   └── widgets/
        │       ├── payment_summary_card.dart   ← tarjeta resumen financiero
        │       ├── transaction_list.dart        ← historial de transacciones
        │       └── register_payment_dialog.dart ← dialog para registrar pago manual
        └── services/
            ├── pdf_receipt_service.dart        ← generación de recibos PDF
            └── payu_service.dart               ← integración con PayU

functions/
└── src/
    └── payments/
        ├── create_payu_session.ts              ← Cloud Function: genera sesión de pago
        ├── payu_webhook.ts                     ← Cloud Function: recibe confirmación PayU
        └── reconcile_balances.ts               ← Cloud Function: corrección de inconsistencias

test/
└── features/
    └── payments/
        ├── payment_model_test.dart
        ├── payments_repository_test.dart
        └── payu_signature_test.dart
```

---

## PARTE 1 — Modelos de datos

### `lib/features/payments/data/models/payment_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum PaymentStatus {
  alDia,        // Sin saldo vencido, pagos al corriente
  pendiente,    // Tiene cuota próxima (< 7 días para vencer)
  vencido,      // Tiene cuota vencida sin pagar
  pagadoTotal,  // saldoPendiente == 0, tratamiento 100% pagado
}

enum PaymentMethod {
  efectivo,       // Pago presencial en efectivo
  transferencia,  // Transferencia bancaria (Nequi, Daviplata, banco)
  payu,           // Pago en línea procesado por PayU Colombia
}

// ─── PaymentModel ─────────────────────────────────────────────────────────────

class PaymentModel {
  final String id;                   // IGUAL a patientId — relación 1:1 (BD-03)
  final String patientId;
  final double totalTratamiento;     // Valor total acordado con el paciente (COP)
  final double montoPagado;          // Suma acumulada de todas las transacciones
  final double saldoPendiente;       // totalTratamiento - montoPagado ← FUENTE DE VERDAD
  final DateTime? fechaProximoPago;  // Para recordatorio automático (Bloque 09)
  final PaymentStatus estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentModel({
    required this.id,
    required this.patientId,
    required this.totalTratamiento,
    required this.montoPagado,
    required this.saldoPendiente,
    this.fechaProximoPago,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      totalTratamiento: (json['totalTratamiento'] as num).toDouble(),
      montoPagado: (json['montoPagado'] as num).toDouble(),
      saldoPendiente: (json['saldoPendiente'] as num).toDouble(),
      fechaProximoPago: json['fechaProximoPago'] != null
          ? (json['fechaProximoPago'] as Timestamp).toDate()
          : null,
      estado: PaymentStatus.values.byName(json['estado'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'totalTratamiento': totalTratamiento,
        'montoPagado': montoPagado,
        'saldoPendiente': saldoPendiente,
        'fechaProximoPago': fechaProximoPago != null
            ? Timestamp.fromDate(fechaProximoPago!)
            : null,
        'estado': estado.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  PaymentModel copyWith({
    double? totalTratamiento,
    double? montoPagado,
    double? saldoPendiente,
    DateTime? fechaProximoPago,
    PaymentStatus? estado,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id,
      patientId: patientId,
      totalTratamiento: totalTratamiento ?? this.totalTratamiento,
      montoPagado: montoPagado ?? this.montoPagado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      fechaProximoPago: fechaProximoPago ?? this.fechaProximoPago,
      estado: estado ?? this.estado,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calcula el estado correcto a partir del saldo y la fecha de próximo pago.
  /// Usar este método al registrar cualquier pago para mantener consistencia.
  static PaymentStatus calcularEstado({
    required double saldoPendiente,
    DateTime? fechaProximoPago,
  }) {
    if (saldoPendiente <= 0) return PaymentStatus.pagadoTotal;
    if (fechaProximoPago == null) return PaymentStatus.alDia;
    final hoy = DateTime.now();
    final diferencia = fechaProximoPago.difference(hoy).inDays;
    if (diferencia < 0) return PaymentStatus.vencido;
    if (diferencia <= 7) return PaymentStatus.pendiente;
    return PaymentStatus.alDia;
  }
}

// ─── PaymentTransaction ───────────────────────────────────────────────────────

class PaymentTransaction {
  final String id;
  final double monto;                // Valor pagado en esta transacción (COP)
  final DateTime fecha;
  final PaymentMethod metodo;
  final String? referencia;          // Referencia bancaria, comprobante o ID de PayU
  final String registradoPor;        // adminId si es manual, 'payu_webhook' si es PayU
  final String? notas;               // Observación libre del admin
  final String? reciboUrl;           // URL de Firebase Storage del PDF generado
  final String? payuOrderId;         // ID de la orden en PayU (solo pagos PayU)
  final String? payuTransactionId;   // ID de transacción de PayU (solo pagos PayU)

  const PaymentTransaction({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.metodo,
    this.referencia,
    required this.registradoPor,
    this.notas,
    this.reciboUrl,
    this.payuOrderId,
    this.payuTransactionId,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String,
      monto: (json['monto'] as num).toDouble(),
      fecha: (json['fecha'] as Timestamp).toDate(),
      metodo: PaymentMethod.values.byName(json['metodo'] as String),
      referencia: json['referencia'] as String?,
      registradoPor: json['registradoPor'] as String,
      notas: json['notas'] as String?,
      reciboUrl: json['reciboUrl'] as String?,
      payuOrderId: json['payuOrderId'] as String?,
      payuTransactionId: json['payuTransactionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'monto': monto,
        'fecha': Timestamp.fromDate(fecha),
        'metodo': metodo.name,
        'referencia': referencia,
        'registradoPor': registradoPor,
        'notas': notas,
        'reciboUrl': reciboUrl,
        'payuOrderId': payuOrderId,
        'payuTransactionId': payuTransactionId,
      };
}
```

---

## PARTE 2 — Repositorio

### `lib/features/payments/data/repositories/payments_repository.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../../../../shared/constants/firestore_paths.dart';

class PaymentsRepository {
  final FirebaseFirestore _db;
  PaymentsRepository(this._db);

  // ── Streams ──────────────────────────────────────────────────────────────────

  /// Stream del resumen financiero del paciente.
  /// Acceso directo por patientId — sin query (BD-03).
  Stream<PaymentModel?> watchPatientPayments(String patientId) {
    return _db
        .collection(FirestorePaths.payments)
        .doc(patientId)
        .snapshots()
        .map((snap) =>
            snap.exists ? PaymentModel.fromJson(snap.data()!) : null);
  }

  /// Stream del historial de transacciones ordenado por fecha descendente.
  Stream<List<PaymentTransaction>> watchTransactions(String patientId) {
    return _db
        .collection(FirestorePaths.transactions(patientId))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PaymentTransaction.fromJson(d.data()))
            .toList());
  }

  // ── Escrituras ───────────────────────────────────────────────────────────────

  /// Crear el documento de pagos al registrar un paciente nuevo.
  /// Llamar desde PatientsRepository.createPatient() en el mismo batch.
  Future<void> initializePaymentDocument({
    required String patientId,
    required double totalTratamiento,
  }) async {
    final ref = _db.collection(FirestorePaths.payments).doc(patientId);
    final exists = (await ref.get()).exists;
    if (exists) return; // Idempotente — no sobreescribir si ya existe

    await ref.set({
      'id': patientId,
      'patientId': patientId,
      'totalTratamiento': totalTratamiento,
      'montoPagado': 0.0,
      'saldoPendiente': totalTratamiento,
      'fechaProximoPago': null,
      'estado': PaymentStatus.alDia.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registrar un pago manual hecho por el admin (efectivo / transferencia).
  ///
  /// ⚠️ DAT-01: Batch atómico — actualiza payments/ (fuente de verdad)
  /// y patients/ (cache) en una sola operación.
  Future<void> registerManualPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  }) async {
    // 1. Leer el estado actual ANTES del batch para validar
    final paymentDoc = await _db
        .collection(FirestorePaths.payments)
        .doc(patientId)
        .get();

    if (!paymentDoc.exists) {
      throw Exception(
          'No existe registro de pagos para este paciente. '
          'Asegúrate de que el paciente fue creado correctamente.');
    }

    final paymentData = paymentDoc.data()!;
    final saldoActual = (paymentData['saldoPendiente'] as num).toDouble();
    final totalTratamiento =
        (paymentData['totalTratamiento'] as num).toDouble();

    // 2. Validaciones de negocio
    if (monto <= 0) {
      throw Exception('El monto debe ser mayor a cero.');
    }
    if (monto > saldoActual) {
      throw Exception(
          'El monto ingresado (\$${monto.toStringAsFixed(0)}) '
          'supera el saldo pendiente (\$${saldoActual.toStringAsFixed(0)}).');
    }

    // 3. Calcular nuevo estado
    final nuevoSaldo = saldoActual - monto;
    final nuevoMontoPagado =
        (paymentData['montoPagado'] as num).toDouble() + monto;
    final nuevoEstado = PaymentModel.calcularEstado(
      saldoPendiente: nuevoSaldo,
      fechaProximoPago: paymentData['fechaProximoPago'] != null
          ? (paymentData['fechaProximoPago'] as Timestamp).toDate()
          : null,
    );

    // 4. Batch atómico
    final batch = _db.batch();

    // 4a. Nueva transacción
    final txRef = _db
        .collection(FirestorePaths.transactions(patientId))
        .doc();
    batch.set(txRef, {
      'id': txRef.id,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': metodo.name,
      'referencia': referencia,
      'registradoPor': adminId,
      'notas': notas,
      'reciboUrl': null,  // Se actualiza después de generar el PDF
      'payuOrderId': null,
      'payuTransactionId': null,
    });

    // 4b. Actualizar payments/ (FUENTE DE VERDAD)
    batch.update(
      _db.collection(FirestorePaths.payments).doc(patientId),
      {
        'montoPagado': nuevoMontoPagado,
        'saldoPendiente': nuevoSaldo,
        'estado': nuevoEstado.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // 4c. Actualizar patients/ (CACHE)
    batch.update(
      _db.collection(FirestorePaths.patients).doc(patientId),
      {
        'saldoPendiente': nuevoSaldo,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    // 5. Generar recibo PDF y actualizar la transacción con la URL
    //    Esto se hace fuera del batch porque es una operación de Storage.
    //    Si falla el PDF, el pago YA quedó registrado — no se pierde.
    try {
      // PdfReceiptService se llama desde el provider, no aquí directamente.
      // El provider actualiza reciboUrl en la transacción tras generar el PDF.
    } catch (_) {
      // Silencioso — el pago está registrado, el PDF es secundario.
    }
  }

  /// Registrar un pago confirmado por PayU vía webhook.
  /// Solo debe ser llamado por la Cloud Function payuWebhook — nunca desde el cliente.
  /// La firma MD5 ya fue verificada antes de llegar aquí.
  Future<void> registerGatewayPayment({
    required String patientId,
    required double monto,
    required String payuOrderId,
    required String payuTransactionId,
    required String referencia,
  }) async {
    final paymentDoc = await _db
        .collection(FirestorePaths.payments)
        .doc(patientId)
        .get();

    if (!paymentDoc.exists) {
      throw Exception('No existe registro de pagos para el paciente $patientId.');
    }

    final paymentData = paymentDoc.data()!;
    final saldoActual = (paymentData['saldoPendiente'] as num).toDouble();
    final nuevoSaldo = (saldoActual - monto).clamp(0.0, double.infinity);
    final nuevoMontoPagado =
        (paymentData['montoPagado'] as num).toDouble() + monto;
    final nuevoEstado = PaymentModel.calcularEstado(
      saldoPendiente: nuevoSaldo,
    );

    final batch = _db.batch();

    final txRef = _db
        .collection(FirestorePaths.transactions(patientId))
        .doc();
    batch.set(txRef, {
      'id': txRef.id,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': PaymentMethod.payu.name,
      'referencia': referencia,
      'registradoPor': 'payu_webhook',
      'notas': 'Pago procesado por PayU Colombia',
      'reciboUrl': null,
      'payuOrderId': payuOrderId,
      'payuTransactionId': payuTransactionId,
    });

    batch.update(
      _db.collection(FirestorePaths.payments).doc(patientId),
      {
        'montoPagado': nuevoMontoPagado,
        'saldoPendiente': nuevoSaldo,
        'estado': nuevoEstado.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _db.collection(FirestorePaths.patients).doc(patientId),
      {
        'saldoPendiente': nuevoSaldo,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Actualizar la URL del recibo PDF en la transacción.
  /// Llamado por PdfReceiptService después de subir el PDF a Storage.
  Future<void> updateTransactionReceiptUrl({
    required String patientId,
    required String transactionId,
    required String reciboUrl,
  }) async {
    await _db
        .collection(FirestorePaths.transactions(patientId))
        .doc(transactionId)
        .update({'reciboUrl': reciboUrl});
  }

  /// Actualizar la fecha del próximo pago y recalcular estado.
  Future<void> updateNextPaymentDate({
    required String patientId,
    required DateTime fecha,
  }) async {
    final paymentDoc = await _db
        .collection(FirestorePaths.payments)
        .doc(patientId)
        .get();
    if (!paymentDoc.exists) return;

    final saldo =
        (paymentDoc.data()!['saldoPendiente'] as num).toDouble();
    final nuevoEstado = PaymentModel.calcularEstado(
      saldoPendiente: saldo,
      fechaProximoPago: fecha,
    );

    await _db.collection(FirestorePaths.payments).doc(patientId).update({
      'fechaProximoPago': Timestamp.fromDate(fecha),
      'estado': nuevoEstado.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

---

## PARTE 3 — Providers Riverpod

### `lib/features/payments/providers/payments_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/payment_model.dart';
import '../data/repositories/payments_repository.dart';

// ── Repositorio ───────────────────────────────────────────────────────────────

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(FirebaseFirestore.instance);
});

// ── Stream: resumen financiero de un paciente ─────────────────────────────────

final patientPaymentProvider =
    StreamProvider.family<PaymentModel?, String>((ref, patientId) {
  return ref
      .watch(paymentsRepositoryProvider)
      .watchPatientPayments(patientId);
});

// ── Stream: historial de transacciones ───────────────────────────────────────

final patientTransactionsProvider =
    StreamProvider.family<List<PaymentTransaction>, String>((ref, patientId) {
  return ref
      .watch(paymentsRepositoryProvider)
      .watchTransactions(patientId);
});

// ── Notifier: registrar pago manual ──────────────────────────────────────────

class RegisterPaymentNotifier
    extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> registerManual({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(paymentsRepositoryProvider).registerManualPayment(
            patientId: patientId,
            monto: monto,
            metodo: metodo,
            adminId: adminId,
            referencia: referencia,
            notas: notas,
          );

      // Generar recibo PDF (ver PdfReceiptService)
      // El provider de PDF se llama aquí y actualiza reciboUrl cuando termina.
    });
  }
}

final registerPaymentProvider =
    AutoDisposeAsyncNotifierProvider<RegisterPaymentNotifier, void>(
        RegisterPaymentNotifier.new);

// ── Notifier: iniciar pago PayU ───────────────────────────────────────────────

class InitiatePayuPaymentNotifier
    extends AutoDisposeAsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  /// Llama a la Cloud Function createPayuSession y retorna la URL de pago.
  Future<void> initiate({
    required String patientId,
    required double monto,
    required String patientEmail,
    required String patientName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final payuService = ref.read(payuServiceProvider);
      final url = await payuService.createPaymentSession(
        patientId: patientId,
        monto: monto,
        patientEmail: patientEmail,
        patientName: patientName,
      );
      return url;
    });
  }
}

final initiatePayuPaymentProvider =
    AutoDisposeAsyncNotifierProvider<InitiatePayuPaymentNotifier, String?>(
        InitiatePayuPaymentNotifier.new);
```

---

## PARTE 4 — Widgets de UI

### `lib/features/payments/presentation/widgets/payment_summary_card.dart`

```dart
/// Tarjeta de resumen financiero del paciente.
/// Muestra total, pagado, saldo y estado con colores semánticos OCG.
///
/// Uso en tab admin:   PaymentSummaryCard(patientId: patientId, isAdmin: true)
/// Uso en app paciente: PaymentSummaryCard(patientId: patientId, isAdmin: false)
///
/// Layout visual:
/// ┌─────────────────────────────────────────┐
/// │  💳 Resumen financiero        [Estado] │
/// │─────────────────────────────────────────│
/// │  Total tratamiento      $1.500.000 COP │
/// │  Total pagado           $  800.000 COP │
/// │  Saldo pendiente        $  700.000 COP │ ← bronze si > 0
/// │─────────────────────────────────────────│
/// │  📅 Próximo pago: 15 de marzo de 2026  │
/// └─────────────────────────────────────────┘
///
/// Estado semántico:
/// alDia       → OcgColors.success (verde)
/// pendiente   → OcgColors.bronze (ámbar)
/// vencido     → OcgColors.error  (rojo)
/// pagadoTotal → OcgColors.espresso con ícono ✓
///
/// Formato moneda: NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
/// Ejemplo: $1.500.000
```

### `lib/features/payments/presentation/widgets/transaction_list.dart`

```dart
/// Lista del historial de transacciones ordenado por fecha descendente.
///
/// Cada ítem muestra:
/// ┌──────────────────────────────────────────────────────┐
/// │ 🟢 Transferencia bancaria              $300.000 COP  │
/// │    Ref: TRF-2026-0042 · 15 mar 2026                  │
/// │    Registrado por: admin@ocg.co                      │
/// │    [Ver recibo PDF] ← solo si reciboUrl != null      │
/// └──────────────────────────────────────────────────────┘
///
/// Íconos por método:
/// efectivo      → Icons.payments_outlined    (verde claro)
/// transferencia → Icons.account_balance      (azul)
/// payu          → Icons.credit_card          (espresso)
///
/// Si la lista está vacía: OcgEmptyState con ícono Icons.receipt_long_outlined
/// y texto "Sin pagos registrados todavía."
///
/// Usar ListView.separated con Divider(color: OcgColors.sand, height: 1)
/// El botón "Ver recibo PDF" abre la URL en el navegador (url_launcher).
```

### `lib/features/payments/presentation/widgets/register_payment_dialog.dart`

```dart
/// Dialog exclusivo para admin — registrar un pago manual.
///
/// Implementar como ConsumerStatefulWidget para manejar _saving correctamente
/// y evitar el bug de doble envío (mismo patrón que AppointmentDialog).
///
/// Campos del formulario:
///
/// 1. MONTO (obligatorio)
///    TextFormField — teclado numérico
///    Validaciones:
///    - No puede estar vacío
///    - Debe ser > 0
///    - No puede superar el saldoPendiente actual
///    - Si monto == saldoPendiente: mostrar banner informativo
///      "Este pago saldará la deuda completa del paciente ✓"
///
/// 2. MÉTODO DE PAGO (obligatorio)
///    DropdownButtonFormField con opciones:
///    - Efectivo
///    - Transferencia bancaria
///    Si elige Transferencia → aparece campo de referencia (ver punto 3)
///
/// 3. REFERENCIA (condicional — solo si método == transferencia)
///    TextFormField — texto libre, max 100 caracteres
///    HelpText: "Número de comprobante o referencia bancaria"
///
/// 4. NOTAS (opcional)
///    TextFormField multilínea, max 3 líneas, max 300 caracteres
///    HelpText: "Observación interna del admin"
///
/// Botones:
/// - "Registrar pago" → OcgColors.espresso, deshabilitado si _saving
/// - "Cancelar" → estilo outline
///
/// Al confirmar:
/// 1. Validar formulario
/// 2. Llamar a registerPaymentProvider.notifier.registerManual(...)
/// 3. Escuchar AsyncValue: loading → mostrar CircularProgressIndicator en botón
/// 4. Si error → mostrar snackbar con el mensaje del Exception
/// 5. Si éxito → cerrar dialog + snackbar "Pago registrado correctamente ✓"
```

### `lib/features/payments/presentation/patient_payments_screen.dart`

```dart
/// Pantalla de pagos para el paciente autenticado.
/// Accesible desde la navegación inferior de PatientHomeScreen.
///
/// Estructura:
/// Scaffold
/// └── SingleChildScrollView
///     └── Column
///         ├── PaymentSummaryCard(isAdmin: false)     ← solo lectura
///         ├── SizedBox(height: 24)
///         ├── _PayuPaymentButton()                   ← pagar en línea
///         ├── SizedBox(height: 24)
///         ├── Text("Historial de pagos", style: OcgTextStyles.subtitle)
///         └── TransactionList(patientId: patientId)  ← con botón ver recibo
///
/// _PayuPaymentButton:
/// - Visible solo si saldoPendiente > 0
/// - Texto: "Pagar en línea con PayU"
/// - Ícono: Icons.credit_card
/// - Color: OcgColors.espresso
/// - Al tocar: muestra campo de monto → confirma → inicia flujo PayU
/// - Si saldo == 0: mostrar chip "Tratamiento pagado en su totalidad ✓"
///
/// El paciente NO ve el botón "Registrar pago" — ese es exclusivo del admin.
```

### Llenar `lib/features/patients/presentation/tabs/patient_payments_tab.dart`

```dart
/// Tab de pagos dentro de PatientDetailScreen (vista del admin).
///
/// Estructura:
/// Column
/// ├── PaymentSummaryCard(patientId: patientId, isAdmin: true)
/// ├── SizedBox(height: 12)
/// ├── _SetNextPaymentDateRow(patientId: patientId)  ← opcional, para el admin
/// ├── SizedBox(height: 8)
/// ├── ElevatedButton.icon(
/// │     icon: Icon(Icons.add_circle_outline),
/// │     label: Text('Registrar pago'),
/// │     onPressed: () => showDialog(RegisterPaymentDialog(patientId: patientId)),
/// │   )
/// ├── SizedBox(height: 16)
/// └── TransactionList(patientId: patientId)
///
/// _SetNextPaymentDateRow:
/// Fila compacta con texto "Próximo pago:" y un TextButton con la fecha actual
/// que al tocarse abre un DatePicker. Al seleccionar, llama a
/// paymentsRepository.updateNextPaymentDate(patientId, fecha).
```

---

## PARTE 5 — Recibos PDF

### `lib/features/payments/services/pdf_receipt_service.dart`

```dart
/// Genera un recibo PDF de la transacción y lo sube a Firebase Storage.
/// Dependencia: paquete `pdf` (ya en pubspec o agregar: pdf: ^3.10.0)
///              paquete `firebase_storage`
///
/// Estructura del PDF generado:
///
/// ┌────────────────────────────────────────┐
/// │  [LOGO OCG CLÍNICA]                    │
/// │  OCG Clínica Dental                    │
/// │  NIT: XXX-XXXXXXX-X                    │
/// │  Tel: +57 (607) XXX XXXX               │
/// │────────────────────────────────────────│
/// │  RECIBO DE PAGO No. [ID Transacción]   │
/// │  Fecha: 15 de marzo de 2026            │
/// │────────────────────────────────────────│
/// │  Paciente:   María López               │
/// │  Documento:  CC 1.000.000.000          │
/// │────────────────────────────────────────│
/// │  Concepto:   Tratamiento de ortodoncia │
/// │  Método:     Transferencia bancaria    │
/// │  Referencia: TRF-2026-0042             │
/// │────────────────────────────────────────│
/// │  VALOR PAGADO:        $300.000 COP     │
/// │  SALDO PENDIENTE:     $700.000 COP     │
/// │────────────────────────────────────────│
/// │  Registrado por: Admin OCG             │
/// │  "Este documento es prueba de pago."   │
/// └────────────────────────────────────────┘
///
/// Ruta en Storage: payments/{patientId}/recibos/{transactionId}.pdf
/// URL pública: se guarda en la transacción via updateTransactionReceiptUrl()
///
/// Método principal:
/// Future<String> generateAndUpload({
///   required String patientId,
///   required String transactionId,
///   required PaymentTransaction transaction,
///   required PaymentModel paymentSummary,
///   required String patientName,
///   required String patientDocument,
/// })
/// → retorna la URL de descarga del PDF en Storage
```

---

## PARTE 6 — Integración PayU Colombia

### Credenciales de Sandbox (desarrollo y pruebas)

Estas credenciales son públicas y oficiales de PayU para desarrollo.
**Nunca usar en producción.**

```
API Key:      4Vj8eK4rloUd272L48hsrarnUA
Merchant ID:  508029
Account ID:   512321
API Login:    pRRXKOl8ikMmt9u

URL Sandbox:  https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/
URL API:      https://sandbox.api.payulatam.com/payments-api/4.0/service.cgi
```

Tarjetas de prueba oficiales de PayU Colombia:

| Resultado | Número de tarjeta | CVV | Vencimiento |
|-----------|-------------------|-----|-------------|
| ✅ APROBADO | 4097440000000004 | 321 | 12/2030 |
| ❌ RECHAZADO | 4111111111111111 | 321 | 12/2030 |
| ⏳ PENDIENTE | 4444444444449170 | 321 | 12/2030 |

Para PSE en sandbox: usar cualquier banco y cédula ficticia.

### Credenciales de Producción (cuando la doctora tenga cuenta activa)

Obtener desde el panel de PayU Colombia tras aprobación:
- `PAYU_API_KEY` → guardar en Firebase Functions config (nunca en el código)
- `PAYU_MERCHANT_ID`
- `PAYU_ACCOUNT_ID`

```bash
# Configurar en Firebase Functions (no hardcodear)
firebase functions:config:set payu.api_key="VALOR_REAL" payu.merchant_id="VALOR_REAL"
```

### Flujo completo de un pago PayU

```
┌─────────────────────────────────────────────────────────────────────┐
│                   FLUJO DE PAGO PAYU                                │
│                                                                     │
│  1. Paciente toca "Pagar $300.000"                                  │
│              ↓                                                      │
│  2. Flutter llama Cloud Function createPayuSession                  │
│     Parámetros: patientId, monto, email, nombre                     │
│              ↓                                                      │
│  3. Cloud Function construye la firma MD5:                          │
│     firma = MD5(apiKey~merchantId~referencia~monto~COP)             │
│     Genera referencia única: OCG-{timestamp}-{patientId}            │
│     Retorna: { checkoutUrl, referencia }                            │
│              ↓                                                      │
│  4. Flutter abre checkoutUrl en WebView (webview_flutter)           │
│     El paciente ve el formulario SEGURO de PayU                     │
│     El paciente ingresa su tarjeta / elige PSE                      │
│              ↓                                                      │
│  5. PayU procesa el pago con el banco                               │
│              ↓                                                      │
│  6. PayU hace POST al webhook:                                      │
│     https://{region}-{project}.cloudfunctions.net/payuWebhook       │
│     Body: { state_pol, reference_sale, value, sign, ... }           │
│              ↓                                                      │
│  7. Cloud Function payuWebhook:                                     │
│     a. Recibe el POST                                               │
│     b. Verifica firma MD5 (seguridad crítica)                       │
│     c. Si estado == APPROVED → llama registerGatewayPayment()       │
│     d. Si estado == DECLINED → registra log, no actualiza saldo     │
│     e. Genera recibo PDF y envía notificación push                  │
│              ↓                                                      │
│  8. Stream de Firestore detecta el cambio                           │
│     La UI del paciente y del admin se actualizan solos              │
│     El paciente recibe notificación: "Pago confirmado ✓"            │
└─────────────────────────────────────────────────────────────────────┘
```

### `lib/features/payments/services/payu_service.dart`

```dart
/// Servicio Flutter para interactuar con PayU a través de Cloud Functions.
/// No llama a PayU directamente — siempre pasa por Cloud Functions
/// para no exponer las API Keys en el cliente.
///
/// Dependencias:
///   cloud_functions: ^4.0.0  (ya en el proyecto)
///   webview_flutter: ^4.4.0  (agregar a pubspec.yaml)
///
/// Método principal:
/// Future<String> createPaymentSession({
///   required String patientId,
///   required double monto,
///   required String patientEmail,
///   required String patientName,
/// }) → retorna la URL del checkout de PayU
///
/// El flujo en Flutter:
/// 1. Llamar createPaymentSession()
/// 2. Abrir la URL en WebView (PayuCheckoutScreen)
/// 3. Escuchar el navigationDelegate del WebView:
///    - Si navega a la URL de respuesta de PayU (responseUrl) → cerrar WebView
///    - Mostrar al usuario: "Procesando tu pago, espera un momento..."
///    - El resultado llega por el stream de Firestore (webhook actualiza Firestore)

class PayuService {
  final FirebaseFunctions _functions;
  PayuService(this._functions);

  Future<String> createPaymentSession({
    required String patientId,
    required double monto,
    required String patientEmail,
    required String patientName,
  }) async {
    final callable = _functions.httpsCallable('createPayuSession');
    final result = await callable.call({
      'patientId': patientId,
      'monto': monto,
      'email': patientEmail,
      'nombre': patientName,
    });
    return result.data['checkoutUrl'] as String;
  }
}

final payuServiceProvider = Provider<PayuService>((ref) {
  return PayuService(FirebaseFunctions.instance);
});
```

### `lib/features/payments/presentation/payu_checkout_screen.dart`

```dart
/// Pantalla que envuelve el WebView de PayU.
///
/// Estructura:
/// Scaffold
/// ├── AppBar: "Pagar con PayU" + botón cerrar (X)
/// └── WebViewWidget
///     ├── url: checkoutUrl (viene de createPaymentSession)
///     └── navigationDelegate:
///         if url.contains('responseUrl') → Navigator.pop()
///
/// Comportamiento:
/// - Mostrar LinearProgressIndicator mientras carga el WebView
/// - Si el paciente toca X → confirmar con AlertDialog:
///   "¿Deseas cancelar el pago? Tu saldo no ha sido modificado."
/// - Después de cerrar: la pantalla de pagos se actualiza sola
///   gracias al stream de Firestore (si el pago fue exitoso,
///   el webhook ya actualizó el saldo antes de que el paciente vea esta pantalla).
```

---

## PARTE 7 — Cloud Functions (TypeScript)

### `functions/src/payments/create_payu_session.ts`

```typescript
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

/**
 * createPayuSession
 * Callable desde Flutter — genera una sesión de pago en PayU.
 * 
 * Recibe: { patientId, monto, email, nombre }
 * Retorna: { checkoutUrl, referencia }
 * 
 * El monto se recibe en COP (pesos colombianos) como número entero.
 * La referencia generada es única: OCG-{timestamp}-{patientId.slice(0,8)}
 * 
 * La firma MD5 se calcula así (formato oficial PayU Colombia):
 * firma = MD5("apiKey~merchantId~referencia~monto~COP")
 * Ejemplo: MD5("4Vj8eK4rloUd272L48hsrarnUA~508029~OCG-1234567890-abc12345~300000~COP")
 * 
 * La URL del checkout de PayU se construye con parámetros GET:
 * merchantId, accountId, description, referenceCode, amount,
 * currency, signature, responseUrl, confirmationUrl, buyerEmail,
 * buyerFullName
 * 
 * confirmationUrl → URL del webhook payuWebhook (para recibir resultado)
 * responseUrl     → URL de retorno al paciente (puede ser una página en blanco
 *                   que el WebView detecta para cerrar automáticamente)
 * 
 * Ambiente:
 * - Sandbox: usa credenciales de prueba y URL sandbox.checkout.payulatam.com
 * - Producción: usa Firebase Functions config y checkout.payulatam.com
 */
export const createPayuSession = functions.https.onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated', 'Debes estar autenticado.'
      );
    }

    const { patientId, monto, email, nombre } = request.data;

    // Validaciones básicas
    if (!patientId || !monto || monto <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument', 'Parámetros inválidos.'
      );
    }

    // Credenciales (sandbox o producción según config)
    const isSandbox = process.env.PAYU_SANDBOX === 'true';
    const apiKey = isSandbox
      ? '4Vj8eK4rloUd272L48hsrarnUA'
      : functions.params.defineString('PAYU_API_KEY').value();
    const merchantId = isSandbox ? '508029' : functions.params.defineString('PAYU_MERCHANT_ID').value();
    const accountId  = isSandbox ? '512321' : functions.params.defineString('PAYU_ACCOUNT_ID').value();

    // Referencia única
    const referencia = `OCG-${Date.now()}-${patientId.slice(0, 8)}`;
    const montoStr = monto.toFixed(2);

    // Firma MD5 — formato oficial PayU
    const firmaStr = `${apiKey}~${merchantId}~${referencia}~${montoStr}~COP`;
    const firma = crypto.createHash('md5').update(firmaStr).digest('hex');

    // URL base de PayU
    const baseUrl = isSandbox
      ? 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/'
      : 'https://checkout.payulatam.com/ppp-web-gateway-payu/';

    // URL del webhook (confirmación de PayU → tu Cloud Function)
    const webhookUrl = isSandbox
      ? 'https://us-central1-TU_PROYECTO.cloudfunctions.net/payuWebhook'
      : `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/payuWebhook`;

    // Construir URL de checkout
    const params = new URLSearchParams({
      merchantId,
      accountId,
      description: 'Tratamiento de ortodoncia - OCG Clínica',
      referenceCode: referencia,
      amount: montoStr,
      currency: 'COP',
      signature: firma,
      responseUrl: webhookUrl + '?type=response',
      confirmationUrl: webhookUrl,
      buyerEmail: email,
      buyerFullName: nombre,
      lng: 'es',
    });

    const checkoutUrl = `${baseUrl}?${params.toString()}`;

    // Guardar la referencia en Firestore para auditoría
    await admin.firestore()
      .collection('payu_sessions')
      .doc(referencia)
      .set({
        patientId,
        monto,
        referencia,
        estado: 'pendiente',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { checkoutUrl, referencia };
  }
);
```

### `functions/src/payments/payu_webhook.ts`

```typescript
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

/**
 * payuWebhook
 * HTTP endpoint que recibe la confirmación de PayU tras procesar un pago.
 * 
 * ⚠️ SEGURIDAD CRÍTICA: Antes de hacer cualquier cosa, verificar la firma MD5.
 * Si la firma no coincide, rechazar el request con 401. Esto evita que
 * alguien externo finja ser PayU y marque pagos como aprobados.
 * 
 * Verificación de firma PayU:
 * firmaEsperada = MD5("apiKey~merchantId~referencia~monto~moneda~state_pol")
 * Comparar con el campo 'sign' del body del POST.
 * 
 * state_pol de PayU:
 * 4 = APROBADO  → registrar pago, generar recibo
 * 6 = RECHAZADO → solo registrar log
 * 7 = PENDIENTE → registrar log, esperar confirmación final
 * 
 * Campos del POST de PayU (los más importantes):
 * - merchant_id
 * - reference_sale   → referencia que generamos en createPayuSession
 * - value            → monto cobrado
 * - currency         → COP
 * - state_pol        → 4=aprobado, 6=rechazado, 7=pendiente
 * - sign             → firma MD5 para verificar
 * - transaction_id   → ID único de PayU
 * - order_id         → ID de la orden en PayU
 * 
 * Flujo de ejecución:
 * 1. Recibir POST
 * 2. Verificar firma MD5 → si falla, retornar 401
 * 3. Si state_pol == 4 (aprobado):
 *    a. Buscar patientId desde la referencia en payu_sessions
 *    b. Llamar PaymentsRepository.registerGatewayPayment()
 *    c. Actualizar payu_sessions con estado 'aprobado'
 *    d. Disparar notificación push (opcional en este bloque, obligatorio en Bloque 09)
 * 4. Si state_pol == 6 (rechazado):
 *    a. Actualizar payu_sessions con estado 'rechazado'
 *    b. Disparar notificación push informando al paciente
 * 5. Retornar 200 (PayU reintenta si no recibe 200)
 */
export const payuWebhook = functions.https.onRequest(
  { cors: false },
  async (req, res) => {
    try {
      const body = req.body;

      // 1. Verificar firma MD5
      const isSandbox = process.env.PAYU_SANDBOX === 'true';
      const apiKey = isSandbox
        ? '4Vj8eK4rloUd272L48hsrarnUA'
        : process.env.PAYU_API_KEY!;

      const firmaStr = [
        apiKey,
        body.merchant_id,
        body.reference_sale,
        parseFloat(body.value).toFixed(1),
        body.currency,
        body.state_pol,
      ].join('~');

      const firmaCalculada = crypto
        .createHash('md5')
        .update(firmaStr)
        .digest('hex');

      if (firmaCalculada !== body.sign) {
        console.error('Firma inválida — posible intento de fraude');
        res.status(401).send('Firma inválida');
        return;
      }

      // 2. Buscar la sesión de pago
      const sessionSnap = await admin.firestore()
        .collection('payu_sessions')
        .doc(body.reference_sale)
        .get();

      if (!sessionSnap.exists) {
        console.error(`Referencia no encontrada: ${body.reference_sale}`);
        res.status(200).send('OK'); // Retornar 200 para que PayU no reintente
        return;
      }

      const session = sessionSnap.data()!;
      const { patientId, monto } = session;

      // 3. Procesar según estado
      const statePol = parseInt(body.state_pol);

      if (statePol === 4) {
        // APROBADO
        const db = admin.firestore();
        const batch = db.batch();

        // Crear transacción
        const txRef = db
          .collection(`payments/${patientId}/transactions`)
          .doc();
        batch.set(txRef, {
          id: txRef.id,
          monto: parseFloat(body.value),
          fecha: admin.firestore.FieldValue.serverTimestamp(),
          metodo: 'payu',
          referencia: body.reference_sale,
          registradoPor: 'payu_webhook',
          notas: 'Pago procesado por PayU Colombia',
          reciboUrl: null,
          payuOrderId: body.order_id,
          payuTransactionId: body.transaction_id,
        });

        // Leer saldo actual para calcular nuevo estado
        const paymentDoc = await db.collection('payments').doc(patientId).get();
        const saldoActual = (paymentDoc.data()!['saldoPendiente'] as number);
        const montoIngresado = parseFloat(body.value);
        const nuevoSaldo = Math.max(0, saldoActual - montoIngresado);
        const nuevoEstado = nuevoSaldo <= 0 ? 'pagadoTotal' : 'alDia';

        // Actualizar payments/ (fuente de verdad)
        batch.update(db.collection('payments').doc(patientId), {
          montoPagado: admin.firestore.FieldValue.increment(montoIngresado),
          saldoPendiente: nuevoSaldo,
          estado: nuevoEstado,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Actualizar patients/ (cache)
        batch.update(db.collection('patients').doc(patientId), {
          saldoPendiente: nuevoSaldo,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await batch.commit();

        // Actualizar sesión a aprobado
        await sessionSnap.ref.update({ estado: 'aprobado' });

        console.log(`Pago aprobado: ${body.reference_sale} - $${body.value} COP`);

      } else if (statePol === 6) {
        // RECHAZADO
        await sessionSnap.ref.update({ estado: 'rechazado' });
        console.log(`Pago rechazado: ${body.reference_sale}`);

      } else if (statePol === 7) {
        // PENDIENTE
        await sessionSnap.ref.update({ estado: 'pendiente_confirmacion' });
        console.log(`Pago pendiente: ${body.reference_sale}`);
      }

      res.status(200).send('OK');

    } catch (error) {
      console.error('Error en payuWebhook:', error);
      res.status(500).send('Error interno');
    }
  }
);
```

### `functions/src/payments/reconcile_balances.ts`

```typescript
/**
 * reconcilePatientBalances
 * Callable — solo admin.
 * 
 * Corrige inconsistencias entre payments/{id}.saldoPendiente
 * y patients/{id}.saldoPendiente.
 * 
 * Usar si se sospecha desincronización por fallo de red a mitad de un batch.
 * Ejecutar manualmente desde la app admin (botón oculto en configuración).
 * 
 * Proceso:
 * 1. Lee todos los documentos de payments/
 * 2. Para cada uno, actualiza patients/{id}.saldoPendiente con el valor de payments/
 * 3. Retorna cuántos documentos fueron corregidos
 */
export const reconcilePatientBalances = functions.https.onCall(
  { cors: true },
  async (request) => {
    if (request.auth?.token?.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado.');
    }

    const paymentsSnap = await admin.firestore().collection('payments').get();
    const batch = admin.firestore().batch();
    let fixed = 0;

    for (const paymentDoc of paymentsSnap.docs) {
      const payment = paymentDoc.data();
      const patientRef = admin.firestore()
        .collection('patients')
        .doc(payment.patientId);

      batch.update(patientRef, {
        saldoPendiente: payment.saldoPendiente,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      fixed++;
    }

    await batch.commit();
    return { fixed, message: `${fixed} pacientes reconciliados correctamente.` };
  }
);
```

---

## PARTE 8 — Reglas de Firestore para pagos

Agregar a `firestore.rules`:

```
// Colección payments — acceso directo por patientId
match /payments/{patientId} {
  // Admin puede leer y escribir cualquier documento
  allow read, write: if request.auth.token.role == 'admin';

  // Paciente solo puede leer su propio documento de pagos
  allow read: if request.auth.uid == patientId;

  // Paciente NO puede escribir directamente en payments/
  // Los pagos solo se crean por el admin o por la Cloud Function del webhook

  match /transactions/{transactionId} {
    // Admin puede leer y escribir transacciones
    allow read, write: if request.auth.token.role == 'admin';

    // Paciente puede leer sus propias transacciones
    allow read: if request.auth.uid == patientId;
  }
}

// Colección payu_sessions — solo Cloud Functions
match /payu_sessions/{sessionId} {
  allow read, write: if false; // Solo acceso desde admin SDK (Cloud Functions)
}
```

---

## PARTE 9 — Índices Firestore requeridos

Agregar a `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "transactions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "fecha", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "transactions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "metodo", "order": "ASCENDING" },
        { "fieldPath": "fecha", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## PARTE 10 — Tests

### `test/features/payments/payment_model_test.dart`

```dart
/// Tests de serialización:
/// ✓ fromJson con todos los campos completos
/// ✓ fromJson con fechaProximoPago null
/// ✓ toJson y vuelta con fromJson (roundtrip) da el mismo resultado
/// ✓ calcularEstado: saldo = 0 → pagadoTotal
/// ✓ calcularEstado: sin fecha → alDia
/// ✓ calcularEstado: fecha vencida → vencido
/// ✓ calcularEstado: fecha en 3 días → pendiente
/// ✓ calcularEstado: fecha en 15 días → alDia
///
/// Tests de PaymentTransaction:
/// ✓ fromJson con reciboUrl null
/// ✓ fromJson con payuOrderId y payuTransactionId
/// ✓ roundtrip toJson → fromJson
```

### `test/features/payments/payu_signature_test.dart`

```dart
/// Tests de verificación de firma MD5 de PayU:
/// ✓ Firma calculada coincide con ejemplo oficial de PayU
/// ✓ Firma falla si apiKey es incorrecto
/// ✓ Firma falla si monto tiene formato incorrecto
/// 
/// Ejemplo oficial de PayU para Colombia:
/// apiKey:    4Vj8eK4rloUd272L48hsrarnUA
/// merchantId: 508029
/// referencia: TestPayU
/// monto:      150000.00 → (formato con 1 decimal para el hash)
/// moneda:     COP
/// state_pol:  4
/// firma esperada: d2f8c4b2c6c0f2b8f1...  (verificar en docs PayU)
```

### `test/features/payments/payments_repository_test.dart`

```dart
/// Tests con Firebase Emulator:
/// ✓ initializePaymentDocument crea el documento correctamente
/// ✓ initializePaymentDocument es idempotente (no sobreescribe)
/// ✓ registerManualPayment actualiza payments/ y patients/ en batch
/// ✓ registerManualPayment falla si monto > saldoPendiente
/// ✓ registerManualPayment falla si monto <= 0
/// ✓ registerManualPayment actualiza estado a pagadoTotal cuando saldo llega a 0
/// ✓ watchTransactions retorna lista vacía cuando no hay transacciones
/// ✓ watchTransactions retorna transacciones en orden descendente por fecha
```

---

## PARTE 11 — Cómo probar este bloque (sandbox)

### Herramientas necesarias

```bash
# 1. Firebase Emulators (ya instalado)
firebase emulators:start

# 2. ngrok para exponer el webhook al internet
# Instalar: https://ngrok.com/download
ngrok http 5001  # El puerto de Firebase Functions en emulador
```

### Paso a paso para probar PayU en sandbox

```
1. Correr emuladores:
   firebase emulators:start --only functions,firestore

2. Correr ngrok en otra terminal:
   ngrok http 5001
   → Obtendrás una URL como: https://abc123.ngrok-free.app

3. En create_payu_session.ts, reemplazar webhookUrl con la URL de ngrok:
   const webhookUrl = 'https://abc123.ngrok-free.app/TU_PROYECTO/us-central1/payuWebhook';

4. Abrir la app → ir a pantalla de pagos del paciente → "Pagar con PayU"

5. En el WebView, usar la tarjeta aprobada:
   Número: 4097440000000004
   CVV: 321
   Vencimiento: 12/2030
   Nombre: APPROVED

6. PayU sandbox procesará el pago y enviará el webhook a tu ngrok

7. En la terminal del emulador verás el log: "Pago aprobado: OCG-xxx"

8. La UI del paciente se actualiza sola — el saldo baja automáticamente

9. Para probar rechazo, usar tarjeta: 4111111111111111
```

### Checklist de pruebas manuales

```
PAGOS MANUALES (admin):
□ Admin registra pago en efectivo → saldo baja en tiempo real
□ Admin registra pago por transferencia con referencia → aparece en historial
□ Admin intenta pago mayor al saldo → error claro, nada se escribe
□ Admin paga el saldo exacto → estado cambia a "Pagado total" (chip verde)
□ Dos pantallas abiertas: admin y paciente → al registrar pago, ambas se actualizan

PAGOS PAYU:
□ Paciente toca "Pagar con PayU" → se abre WebView con formulario
□ Pago aprobado con tarjeta 4097440000000004 → saldo baja, notificación aparece
□ Pago rechazado con tarjeta 4111111111111111 → mensaje de error, saldo no cambia
□ X en WebView → confirma cancelación, saldo no cambia

RECIBOS PDF:
□ Tras pago exitoso → aparece botón "Ver recibo" en la transacción
□ Botón "Ver recibo" abre el PDF en el navegador

FIREBASE CONSOLE (verificación de datos):
□ payments/{uid} → saldoPendiente correcto
□ patients/{uid} → saldoPendiente igual al de payments/
□ payments/{uid}/transactions/ → transacción con todos los campos
□ payu_sessions/{ref} → estado "aprobado" tras pago exitoso

CONSISTENCIA:
□ Correr reconcilePatientBalances desde app admin → retorna 0 correcciones
   (significa que todos los saldos ya estaban sincronizados)
```

---

## Dependencias a agregar en `pubspec.yaml`

```yaml
dependencies:
  webview_flutter: ^4.4.0     # WebView para checkout PayU
  pdf: ^3.10.0                 # Generación de PDFs
  printing: ^5.11.0            # Previsualización/impresión del PDF
  url_launcher: ^6.2.0         # Abrir recibos PDF en navegador
  intl: ^0.18.0                # Ya existe — formato de moneda COP
```

---

## Orden de ejecución recomendado

```
Paso 1:  PaymentModel + PaymentTransaction + enums + tests de serialización
Paso 2:  PaymentsRepository (todos los métodos) + tests con emulator
Paso 3:  payments_provider Riverpod
Paso 4:  PaymentSummaryCard widget
Paso 5:  TransactionList widget
Paso 6:  RegisterPaymentDialog
Paso 7:  Llenar patient_payments_tab.dart (admin)
Paso 8:  PatientPaymentsScreen (paciente)
Paso 9:  PdfReceiptService + tests
Paso 10: PayuService en Flutter
Paso 11: PayuCheckoutScreen (WebView)
Paso 12: Cloud Function createPayuSession
Paso 13: Cloud Function payuWebhook + tests de firma MD5
Paso 14: Cloud Function reconcileBalances
Paso 15: Reglas Firestore + índices
Paso 16: Pruebas manuales con sandbox (checklist completo)
Paso 17: flutter analyze ✅ + flutter test ✅
```

---

## Criterios de cierre del bloque

- [ ] Admin puede registrar pagos en efectivo y transferencia desde el tab del paciente
- [ ] El saldo se actualiza en tiempo real en ambas pantallas (admin + paciente)
- [ ] El historial de transacciones es visible, ordenado y completo
- [ ] El estado del pago cambia automáticamente al llegar a saldo cero
- [ ] El paciente puede iniciar un pago con PayU desde su pantalla
- [ ] Pago aprobado en sandbox actualiza Firestore correctamente (webhook verificado)
- [ ] Pago rechazado en sandbox no modifica el saldo
- [ ] Recibo PDF se genera y queda disponible para descarga tras cada pago
- [ ] Batch atómico: payments/ y patients/ siempre sincronizados (DAT-01)
- [ ] Validación impide: monto negativo, monto mayor al saldo
- [ ] Reglas Firestore: paciente no puede escribir en payments/ directamente
- [ ] reconcileBalances disponible para el admin como herramienta de emergencia
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ (serialización, validaciones, firma MD5)