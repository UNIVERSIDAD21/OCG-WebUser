import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../models/payment_model.dart';

class PaymentsRepository {
  PaymentsRepository(this._db);

  final FirebaseFirestore _db;

  void _trace(String action, Map<String, Object?> details) {
    // ignore: avoid_print
    print('[PaymentsRepository][$action] $details');
  }

  DocumentReference<Map<String, dynamic>> _legacyPaymentRef(String patientId) =>
      _db.doc(FirestorePaths.paymentDoc(patientId));

  DocumentReference<Map<String, dynamic>> _treatmentPaymentRef(
    String patientId,
    String treatmentId,
  ) => _db.doc(FirestorePaths.treatmentPaymentDoc(patientId, treatmentId));

  DocumentReference<Map<String, dynamic>> _patientRef(String patientId) =>
      _db.collection(FirestorePaths.patients).doc(patientId);

  DocumentReference<Map<String, dynamic>> _treatmentRef(
    String patientId,
    String treatmentId,
  ) => _db.doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId));

  Stream<PaymentModel?> watchPatientPayments(
    String patientId, {
    String? treatmentId,
  }) {
    if (treatmentId != null && treatmentId.isNotEmpty) {
      return _watchTreatmentPayment(patientId, treatmentId);
    }

    return _db
        .collection(FirestorePaths.treatmentPayments(patientId))
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isNotEmpty) {
            final payments = snap.docs
                .map((doc) => PaymentModel.fromJson(doc.data()))
                .toList();
            return _buildAggregatePayment(patientId, payments);
          }

          final legacy = await _legacyPaymentRef(patientId).get();
          final legacyData = legacy.data();
          if (legacy.exists && legacyData != null) {
            return PaymentModel.fromJson(legacyData);
          }
          return null;
        });
  }

  Stream<PaymentModel?> _watchTreatmentPayment(
    String patientId,
    String treatmentId,
  ) {
    _trace('watchTreatmentPayment', {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'path': FirestorePaths.treatmentPaymentDoc(patientId, treatmentId),
    });
    return _treatmentPaymentRef(patientId, treatmentId).snapshots().asyncMap((
      snap,
    ) async {
      final data = snap.data();
      if (snap.exists && data != null) {
        return PaymentModel.fromJson(data);
      }

      return _migrateLegacyTreatmentPaymentIfNeeded(
        patientId: patientId,
        treatmentId: treatmentId,
      );
    });
  }

  Stream<List<PaymentTransaction>> watchTransactions(
    String patientId, {
    String? treatmentId,
  }) {
    if (treatmentId != null && treatmentId.isNotEmpty) {
      return _watchTreatmentTransactions(patientId, treatmentId);
    }

    return _db
        .collectionGroup('transactions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PaymentTransaction.fromJson(d.data()))
              .toList(),
        );
  }

  Stream<List<PaymentTransaction>> _watchTreatmentTransactions(
    String patientId,
    String treatmentId,
  ) {
    _trace('watchTreatmentTransactions', {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'path': FirestorePaths.treatmentTransactions(patientId, treatmentId),
    });
    return _db
        .collection(
          FirestorePaths.treatmentTransactions(patientId, treatmentId),
        )
        .orderBy('fecha', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isNotEmpty) {
            return snap.docs
                .map((d) => PaymentTransaction.fromJson(d.data()))
                .toList();
          }

          await _migrateLegacyTransactionsIfNeeded(
            patientId: patientId,
            treatmentId: treatmentId,
          );
          final migrated = await _db
              .collection(
                FirestorePaths.treatmentTransactions(patientId, treatmentId),
              )
              .orderBy('fecha', descending: true)
              .get();
          return migrated.docs
              .map((d) => PaymentTransaction.fromJson(d.data()))
              .toList();
        });
  }

  Future<PaymentModel?> getPatientPayment(
    String patientId, {
    String? treatmentId,
  }) async {
    if (treatmentId != null && treatmentId.isNotEmpty) {
      final treatmentDoc = await _treatmentPaymentRef(
        patientId,
        treatmentId,
      ).get();
      final treatmentData = treatmentDoc.data();
      if (treatmentDoc.exists && treatmentData != null) {
        return PaymentModel.fromJson(treatmentData);
      }
      return _migrateLegacyTreatmentPaymentIfNeeded(
        patientId: patientId,
        treatmentId: treatmentId,
      );
    }

    final treatmentsSnap = await _db
        .collection(FirestorePaths.treatmentPayments(patientId))
        .get();
    if (treatmentsSnap.docs.isNotEmpty) {
      return _buildAggregatePayment(
        patientId,
        treatmentsSnap.docs
            .map((doc) => PaymentModel.fromJson(doc.data()))
            .toList(),
      );
    }

    final snap = await _legacyPaymentRef(patientId).get();
    final data = snap.data();
    if (snap.exists && data != null) {
      return PaymentModel.fromJson(data);
    }
    return null;
  }

  Future<PaymentTransaction?> getLatestTransaction(
    String patientId, {
    String? treatmentId,
  }) async {
    final collectionPath = treatmentId != null && treatmentId.isNotEmpty
        ? FirestorePaths.treatmentTransactions(patientId, treatmentId)
        : FirestorePaths.legacyTransactions(patientId);

    final snap = await _db
        .collection(collectionPath)
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return PaymentTransaction.fromJson(snap.docs.first.data());
    }

    if (treatmentId != null && treatmentId.isNotEmpty) {
      await _migrateLegacyTransactionsIfNeeded(
        patientId: patientId,
        treatmentId: treatmentId,
      );
      final migrated = await _db
          .collection(
            FirestorePaths.treatmentTransactions(patientId, treatmentId),
          )
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();
      if (migrated.docs.isNotEmpty) {
        return PaymentTransaction.fromJson(migrated.docs.first.data());
      }
    }

    return null;
  }

  Future<void> initializePaymentDocument({
    required String patientId,
    required double totalTratamiento,
    String? treatmentId,
  }) async {
    if (treatmentId == null || treatmentId.isEmpty) {
      final ref = _legacyPaymentRef(patientId);
      final doc = await ref.get();
      if (doc.exists) return;

      final now = DateTime.now();
      final saldo = totalTratamiento < 0 ? 0.0 : totalTratamiento;

      await ref.set({
        'id': patientId,
        'patientId': patientId,
        'totalTratamiento': totalTratamiento,
        'montoPagado': 0.0,
        'saldoPendiente': saldo,
        'fechaProximoPago': null,
        'estado': PaymentModel.calcularEstado(
          saldoPendiente: saldo,
          fechaProximoPago: null,
          now: now,
        ).name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
        'legacyMirror': true,
      }, SetOptions(merge: true));
      return;
    }

    final treatmentRef = _treatmentRef(patientId, treatmentId);
    final treatmentSnap = await treatmentRef.get();
    if (!treatmentSnap.exists) {
      throw Exception('TREATMENT_DOC_NOT_FOUND');
    }

    final treatment = PatientTreatment.fromJson(
      treatmentSnap.data()!,
      id: treatmentId,
    );
    await ensureTreatmentPaymentAccount(
      patientId: patientId,
      treatment: treatment,
    );
  }

  Future<void> ensureTreatmentPaymentAccount({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    final ref = _treatmentPaymentRef(patientId, treatment.id);
    final doc = await ref.get();
    if (doc.exists) return;

    final migrated = await _migrateLegacyTreatmentPaymentIfNeeded(
      patientId: patientId,
      treatmentId: treatment.id,
      treatment: treatment,
    );
    if (migrated != null) return;

    final total = treatment.totalTratamiento ?? 0;
    final saldo = (treatment.saldoPendiente ?? total)
        .clamp(0, double.infinity)
        .toDouble();
    final pagado = (total - saldo).clamp(0, double.infinity).toDouble();
    final now = DateTime.now();

    await ref.set({
      'id': treatment.id,
      'patientId': patientId,
      'treatmentId': treatment.id,
      'totalTratamiento': total,
      'montoPagado': pagado,
      'saldoPendiente': saldo,
      'fechaProximoPago': null,
      'estado': PaymentModel.calcularEstado(
        saldoPendiente: saldo,
        fechaProximoPago: null,
        now: now,
      ).name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 2,
      'legacyMigrated': false,
    }, SetOptions(merge: true));
  }

  Future<void> registerManualPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? treatmentId,
    String? referencia,
    String? notas,
  }) async {
    await _registerPayment(
      patientId: patientId,
      monto: monto,
      metodo: metodo,
      registradoPor: adminId,
      treatmentId: treatmentId,
      referencia: referencia,
      notas: notas,
    );
  }

  Future<void> registerGatewayPayment({
    required String patientId,
    required double monto,
    required String payuOrderId,
    required String payuTransactionId,
    String? treatmentId,
    String? referencia,
    String? notas,
  }) async {
    await _registerPayment(
      patientId: patientId,
      monto: monto,
      metodo: PaymentMethod.payu,
      registradoPor: 'payu_webhook',
      treatmentId: treatmentId,
      referencia: referencia,
      notas: notas,
      payuOrderId: payuOrderId,
      payuTransactionId: payuTransactionId,
    );
  }

  Future<void> _registerPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String registradoPor,
    String? treatmentId,
    String? referencia,
    String? notas,
    String? payuOrderId,
    String? payuTransactionId,
  }) async {
    _trace('registerPayment.start', {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'monto': monto,
      'metodo': metodo.name,
      'paymentPath': treatmentId == null
          ? null
          : FirestorePaths.treatmentPaymentDoc(patientId, treatmentId),
      'transactionsPath': treatmentId == null
          ? null
          : FirestorePaths.treatmentTransactions(patientId, treatmentId),
      'treatmentPath': treatmentId == null
          ? null
          : FirestorePaths.patientTreatmentDoc(patientId, treatmentId),
    });
    if (monto <= 0) {
      throw Exception('PAYMENT_AMOUNT_INVALID');
    }
    if (treatmentId == null || treatmentId.isEmpty) {
      throw Exception('TREATMENT_ID_REQUIRED');
    }

    final treatmentDoc = await _treatmentRef(patientId, treatmentId).get();
    if (!treatmentDoc.exists) {
      throw Exception('TREATMENT_DOC_NOT_FOUND');
    }

    final treatment = PatientTreatment.fromJson(
      treatmentDoc.data()!,
      id: treatmentId,
    );
    await ensureTreatmentPaymentAccount(
      patientId: patientId,
      treatment: treatment,
    );

    final paymentRef = _treatmentPaymentRef(patientId, treatmentId);
    final paymentDoc = await paymentRef.get();
    final paymentData = paymentDoc.data() ?? <String, dynamic>{};
    final targetTotal =
        (paymentData['totalTratamiento'] as num?)?.toDouble() ??
        treatment.totalTratamiento ??
        0;
    final targetSaldo =
        (paymentData['saldoPendiente'] as num?)?.toDouble() ??
        treatment.saldoPendiente ??
        targetTotal;
    final targetPaid =
        (paymentData['montoPagado'] as num?)?.toDouble() ??
        (targetTotal - targetSaldo).clamp(0, double.infinity).toDouble();
    final fechaProximoPago = _parseNullableDate(
      paymentData['fechaProximoPago'],
    );

    if (monto > targetSaldo) {
      throw Exception('PAYMENT_EXCEEDS_BALANCE');
    }

    final nuevoSaldo = (targetSaldo - monto)
        .clamp(0, double.infinity)
        .toDouble();
    final nuevoPagado = (targetPaid + monto)
        .clamp(0, double.infinity)
        .toDouble();
    final nuevoEstado = PaymentModel.calcularEstado(
      saldoPendiente: nuevoSaldo,
      fechaProximoPago: fechaProximoPago,
    );

    final txRef = _db
        .collection(
          FirestorePaths.treatmentTransactions(patientId, treatmentId),
        )
        .doc();
    final batch = _db.batch();

    batch.set(txRef, {
      'id': txRef.id,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': metodo.name,
      'referencia': referencia,
      'registradoPor': registradoPor,
      'notas': notas,
      'reciboUrl': null,
      'payuOrderId': payuOrderId,
      'payuTransactionId': payuTransactionId,
    });

    batch.set(paymentRef, {
      'id': treatmentId,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'totalTratamiento': targetTotal,
      'montoPagado': nuevoPagado,
      'saldoPendiente': nuevoSaldo,
      'estado': nuevoEstado.name,
      'fechaProximoPago': paymentData['fechaProximoPago'],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': paymentData['createdAt'] ?? FieldValue.serverTimestamp(),
      'schemaVersion': 2,
      'legacyMigrated': paymentData['legacyMigrated'] ?? false,
    }, SetOptions(merge: true));

    batch.set(_treatmentRef(patientId, treatmentId), {
      'saldoPendiente': nuevoSaldo,
      'updatedAt': FieldValue.serverTimestamp(),
      'financialSummary.paidAmount': nuevoPagado,
      'financialSummary.pendingAmount': nuevoSaldo,
    }, SetOptions(merge: true));

    if (treatment.isPrimary) {
      batch.set(_legacyPaymentRef(patientId), {
        'id': patientId,
        'patientId': patientId,
        'treatmentId': treatmentId,
        'totalTratamiento': targetTotal,
        'montoPagado': nuevoPagado,
        'saldoPendiente': nuevoSaldo,
        'estado': nuevoEstado.name,
        'fechaProximoPago': paymentData['fechaProximoPago'],
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': paymentData['createdAt'] ?? FieldValue.serverTimestamp(),
        'schemaVersion': 1,
        'legacyMirror': true,
      }, SetOptions(merge: true));

      batch.set(_patientRef(patientId), {
        'primaryTreatmentId': treatmentId,
        'updatedAt': FieldValue.serverTimestamp(),
        'treatmentOverview.financial.totalTratamiento': targetTotal,
        'treatmentOverview.financial.montoPagado': nuevoPagado,
        'treatmentOverview.financial.saldoPendiente': nuevoSaldo,
        'treatmentOverview.source': 'treatment-truth',
        'legacyProjection.financialSource': 'compatibility-only',
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      _trace('registerPayment.success', {
        'patientId': patientId,
        'treatmentId': treatmentId,
        'paymentPath': FirestorePaths.treatmentPaymentDoc(
          patientId,
          treatmentId,
        ),
        'transactionsPath': FirestorePaths.treatmentTransactions(
          patientId,
          treatmentId,
        ),
      });
    } catch (error) {
      _trace('registerPayment.error', {
        'patientId': patientId,
        'treatmentId': treatmentId,
        'paymentPath': FirestorePaths.treatmentPaymentDoc(
          patientId,
          treatmentId,
        ),
        'transactionsPath': FirestorePaths.treatmentTransactions(
          patientId,
          treatmentId,
        ),
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<void> updateTransactionReceiptUrl({
    required String patientId,
    required String transactionId,
    required String reciboUrl,
    String? treatmentId,
  }) async {
    if (treatmentId != null && treatmentId.isNotEmpty) {
      await _db
          .doc(
            '${FirestorePaths.treatmentTransactions(patientId, treatmentId)}/$transactionId',
          )
          .update({'reciboUrl': reciboUrl});
      return;
    }

    await _db
        .collection(FirestorePaths.legacyTransactions(patientId))
        .doc(transactionId)
        .update({'reciboUrl': reciboUrl});
  }

  Future<void> updateNextPaymentDate(
    String patientId,
    DateTime fecha, {
    String? treatmentId,
  }) async {
    if (treatmentId == null || treatmentId.isEmpty) {
      final paymentRef = _legacyPaymentRef(patientId);
      final paymentDoc = await paymentRef.get();
      if (!paymentDoc.exists) {
        throw Exception('PAYMENT_DOC_NOT_FOUND');
      }

      final data = paymentDoc.data()!;
      final saldoActual = (data['saldoPendiente'] as num?)?.toDouble() ?? 0;
      final estado = PaymentModel.calcularEstado(
        saldoPendiente: saldoActual,
        fechaProximoPago: fecha,
      );

      await paymentRef.update({
        'fechaProximoPago': Timestamp.fromDate(fecha),
        'estado': estado.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final treatmentDoc = await _treatmentRef(patientId, treatmentId).get();
    if (!treatmentDoc.exists) {
      throw Exception('TREATMENT_DOC_NOT_FOUND');
    }

    final treatment = PatientTreatment.fromJson(
      treatmentDoc.data()!,
      id: treatmentId,
    );
    await ensureTreatmentPaymentAccount(
      patientId: patientId,
      treatment: treatment,
    );

    final paymentRef = _treatmentPaymentRef(patientId, treatmentId);
    final paymentDoc = await paymentRef.get();
    final data = paymentDoc.data();
    if (!paymentDoc.exists || data == null) {
      throw Exception('PAYMENT_DOC_NOT_FOUND');
    }

    final saldoActual = (data['saldoPendiente'] as num?)?.toDouble() ?? 0;
    final estado = PaymentModel.calcularEstado(
      saldoPendiente: saldoActual,
      fechaProximoPago: fecha,
    );

    final batch = _db.batch();
    batch.update(paymentRef, {
      'fechaProximoPago': Timestamp.fromDate(fecha),
      'estado': estado.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (treatment.isPrimary) {
      batch.set(_legacyPaymentRef(patientId), {
        'fechaProximoPago': Timestamp.fromDate(fecha),
        'estado': estado.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'legacyMirror': true,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<PaymentModel?> _migrateLegacyTreatmentPaymentIfNeeded({
    required String patientId,
    required String treatmentId,
    PatientTreatment? treatment,
  }) async {
    final targetRef = _treatmentPaymentRef(patientId, treatmentId);
    final existing = await targetRef.get();
    if (existing.exists && existing.data() != null) {
      return PaymentModel.fromJson(existing.data()!);
    }

    final resolvedTreatment =
        treatment ?? await _loadTreatment(patientId, treatmentId);
    if (resolvedTreatment == null) return null;

    final legacyRef = _legacyPaymentRef(patientId);
    final legacySnap = await legacyRef.get();
    final legacyData = legacySnap.data();
    final legacyTreatmentId = (legacyData?['treatmentId'] ?? '').toString();
    final canMigrateLegacy =
        legacySnap.exists &&
        legacyData != null &&
        (resolvedTreatment.isPrimary ||
            legacyTreatmentId == treatmentId ||
            legacyTreatmentId.isEmpty);

    if (!canMigrateLegacy) {
      await ensureTreatmentPaymentAccount(
        patientId: patientId,
        treatment: resolvedTreatment,
      );
      final created = await targetRef.get();
      final createdData = created.data();
      return created.exists && createdData != null
          ? PaymentModel.fromJson(createdData)
          : null;
    }

    final legacyTotal =
        (legacyData['totalTratamiento'] as num?)?.toDouble() ??
        resolvedTreatment.totalTratamiento ??
        0;
    final legacyPaid =
        (legacyData['montoPagado'] as num?)?.toDouble() ??
        (legacyTotal -
            ((legacyData['saldoPendiente'] as num?)?.toDouble() ??
                resolvedTreatment.saldoPendiente ??
                legacyTotal));
    final legacySaldo =
        (legacyData['saldoPendiente'] as num?)?.toDouble() ??
        resolvedTreatment.saldoPendiente ??
        (legacyTotal - legacyPaid).clamp(0, double.infinity).toDouble();

    await targetRef.set({
      'id': treatmentId,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'totalTratamiento': legacyTotal,
      'montoPagado': legacyPaid,
      'saldoPendiente': legacySaldo,
      'fechaProximoPago': legacyData['fechaProximoPago'],
      'estado':
          legacyData['estado'] ??
          PaymentModel.calcularEstado(
            saldoPendiente: legacySaldo,
            fechaProximoPago: _parseNullableDate(
              legacyData['fechaProximoPago'],
            ),
          ).name,
      'createdAt': legacyData['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 2,
      'legacyMigrated': true,
      'migratedFrom': FirestorePaths.paymentDoc(patientId),
    }, SetOptions(merge: true));

    final migrated = await targetRef.get();
    final migratedData = migrated.data();
    return migrated.exists && migratedData != null
        ? PaymentModel.fromJson(migratedData)
        : null;
  }

  Future<void> _migrateLegacyTransactionsIfNeeded({
    required String patientId,
    required String treatmentId,
  }) async {
    final targetCollection = _db.collection(
      FirestorePaths.treatmentTransactions(patientId, treatmentId),
    );
    final existing = await targetCollection.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final legacy = await _db
        .collection(FirestorePaths.legacyTransactions(patientId))
        .where('treatmentId', whereIn: <dynamic>[treatmentId, null])
        .get();

    if (legacy.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in legacy.docs) {
      final data = doc.data();
      final txTreatmentId = (data['treatmentId'] ?? '').toString();
      if (txTreatmentId.isNotEmpty && txTreatmentId != treatmentId) continue;
      batch.set(targetCollection.doc(doc.id), {
        ...data,
        'patientId': patientId,
        'treatmentId': treatmentId,
        'migratedFrom':
            '${FirestorePaths.legacyTransactions(patientId)}/${doc.id}',
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  PaymentModel _buildAggregatePayment(
    String patientId,
    List<PaymentModel> payments,
  ) {
    final now = DateTime.now();
    final total = payments.fold<double>(
      0,
      (accumulator, payment) => accumulator + payment.totalTratamiento,
    );
    final paid = payments.fold<double>(
      0,
      (accumulator, payment) => accumulator + payment.montoPagado,
    );
    final pending = payments.fold<double>(
      0,
      (accumulator, payment) => accumulator + payment.saldoPendiente,
    );
    final nextPaymentDates =
        payments
            .map((payment) => payment.fechaProximoPago)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final nextDate = nextPaymentDates.isEmpty ? null : nextPaymentDates.first;

    return PaymentModel(
      id: patientId,
      patientId: patientId,
      totalTratamiento: total,
      montoPagado: paid,
      saldoPendiente: pending,
      fechaProximoPago: nextDate,
      estado: PaymentModel.calcularEstado(
        saldoPendiente: pending,
        fechaProximoPago: nextDate,
        now: now,
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<PatientTreatment?> _loadTreatment(
    String patientId,
    String treatmentId,
  ) async {
    final snap = await _treatmentRef(patientId, treatmentId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return PatientTreatment.fromJson(data, id: treatmentId);
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
