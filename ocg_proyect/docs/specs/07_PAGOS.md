# 07 — Gestión de Pagos [CORREGIDO v2.0]

## ⚠️ VERSIÓN CORREGIDA — Correcciones DAT-01, BD-03 aplicadas

- **BD-03**: payments usa patientId como ID (acceso directo, sin query)
- **DAT-01**: saldoPendiente en payments es FUENTE DE VERDAD

---

## Reglas de negocio de pagos

1. Solo el admin puede registrar pagos en efectivo o transferencia.
2. El paciente puede pagar en línea mediante Epayco (tarjeta, PSE, Efecty).
3. Cuando Epayco confirma un pago exitoso, una Cloud Function actualiza montoPagado y saldoPendiente.
4. El saldo nunca puede quedar negativo. Si el monto supera el total, mostrar advertencia al admin.
5. Generar automáticamente un recibo en PDF al confirmar cualquier pago.

---

## ⚠️ DAT-01: saldoPendiente — Fuente de verdad y CACHE

El campo `saldoPendiente` existe en dos lugares:
- **`payments/{patientId}.saldoPendiente`** ← FUENTE DE VERDAD (siempre la usas para cálculos)
- **`patients/{patientId}.saldoPendiente`** ← CACHE (solo para listas, facilita UI)

**Regla de oro:** Todos los cálculos de saldo usan `payments/{patientId}.saldoPendiente`. El campo en patients/ se actualiza después en un batch.

---

## payments_repository.dart [DAT-01 CORREGIDO]

```dart
class PaymentsRepository {
  final FirebaseFirestore _db;

  // BD-03: Acceso directo — paymentId = patientId
  Stream<PaymentModel?> watchPatientPayments(String patientId) {
    return _db
        .collection(FirestorePaths.payments)
        .doc(patientId)  // Acceso DIRECTO, no query
        .snapshots()
        .map((snap) => snap.exists ? PaymentModel.fromJson(snap.data()!) : null);
  }

  Stream<List<PaymentTransaction>> watchTransactions(String patientId) {
    return _db
        .collection(FirestorePaths.transactions(patientId))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PaymentTransaction.fromJson(d.data()))
            .toList());
  }

  // Registrar pago manual (admin)
  // ⚠️ DAT-01: Actualizar payments/ (fuente de verdad) + patients/ (cache)
  Future<void> registerManualPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  }) async {
    final batch = _db.batch();

    // 1. Verificar que saldo no se vuelva negativo
    final paymentDoc = await _db.collection(FirestorePaths.payments).doc(patientId).get();
    if (!paymentDoc.exists) {
      throw Exception('No existe registro de pago para este paciente');
    }

    final paymentData = paymentDoc.data() as Map<String, dynamic>;
    final saldoActual = (paymentData['saldoPendiente'] as num).toDouble();

    if (monto > saldoActual) {
      throw Exception(
        'El monto (\$${monto.toStringAsFixed(0)}) supera el saldo pendiente (\$${saldoActual.toStringAsFixed(0)})',
      );
    }

    // 2. Agregar transacción
    final txRef = _db.collection(FirestorePaths.transactions(patientId)).doc();
    batch.set(txRef, {
      'id': txRef.id,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': metodo.name,
      'referencia': referencia,
      'registradoPor': adminId,
      'notas': notas,
    });

    // 3. Actualizar payment (FUENTE DE VERDAD)
    batch.update(
      _db.collection(FirestorePaths.payments).doc(patientId),
      {
        'montoPagado': FieldValue.increment(monto),
        'saldoPendiente': FieldValue.increment(-monto),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // 4. Actualizar patient (CACHE para listas)
    batch.update(
      _db.collection(FirestorePaths.patients).doc(patientId),
      {
        'saldoPendiente': FieldValue.increment(-monto),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}
```

---

## Cloud Function reconcilePatientBalances [DAT-01]

Si un batch falla a mitad, puede quedar inconsistencia. Esta función reconcilia.

```typescript
export const reconcilePatientBalances = functions
  .https.onCall(async (_, context) => {
    if (context.auth?.token.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'No autorizado');
    }

    const paymentsSnap = await admin
      .firestore()
      .collection('payments')
      .get();

    const batch = admin.firestore().batch();
    let fixed = 0;

    for (const paymentDoc of paymentsSnap.docs) {
      const payment = paymentDoc.data();
      const patientRef = admin
        .firestore()
        .collection('patients')
        .doc(payment.patientId);

      batch.update(patientRef, {
        saldoPendiente: payment.saldoPendiente,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      fixed++;
    }

    await batch.commit();
    return { fixed };
  });
```

Ejecutar semanalmente o manualmente si se detecta inconsistencia.

