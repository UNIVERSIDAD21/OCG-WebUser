import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/payment_model.dart';

class PaymentsRepository {
  PaymentsRepository(this._db);

  final FirebaseFirestore _db;

  Stream<PaymentModel?> watchPatientPayments(String patientId) {
    return _db.collection(FirestorePaths.payments).doc(patientId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return PaymentModel.fromJson(data);
    });
  }

  Stream<List<PaymentTransaction>> watchTransactions(String patientId, {String? treatmentId}) {
    return _db
        .collection(FirestorePaths.transactions(patientId))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PaymentTransaction.fromJson(d.data())).where((tx) {
              if (treatmentId == null || treatmentId.isEmpty) return true;
              return tx.treatmentId == treatmentId;
            }).toList());
  }

  Future<PaymentModel?> getPatientPayment(String patientId) async {
    final snap = await _db.collection(FirestorePaths.payments).doc(patientId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return PaymentModel.fromJson(data);
  }

  Future<PaymentTransaction?> getLatestTransaction(String patientId, {String? treatmentId}) async {
    final snap = await _db
        .collection(FirestorePaths.transactions(patientId))
        .orderBy('fecha', descending: true)
        .get();
    final items = snap.docs.map((doc) => PaymentTransaction.fromJson(doc.data())).where((tx) {
      if (treatmentId == null || treatmentId.isEmpty) return true;
      return tx.treatmentId == treatmentId;
    }).toList();
    if (items.isEmpty) return null;
    return items.first;
  }

  Future<void> initializePaymentDocument({
    required String patientId,
    required double totalTratamiento,
  }) async {
    final ref = _db.collection(FirestorePaths.payments).doc(patientId);
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
    if (monto <= 0) {
      throw Exception('PAYMENT_AMOUNT_INVALID');
    }

    final paymentRef = _db.collection(FirestorePaths.payments).doc(patientId);
    final paymentDoc = await paymentRef.get();

    final treatmentDoc = treatmentId == null || treatmentId.isEmpty
        ? null
        : await _db.doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId)).get();

    if (!paymentDoc.exists && (treatmentDoc == null || !treatmentDoc.exists)) {
      throw Exception('PAYMENT_DOC_NOT_FOUND');
    }

    final paymentData = paymentDoc.data() ?? <String, dynamic>{};
    final treatmentData = treatmentDoc?.data() ?? <String, dynamic>{};

    final targetTotal = (treatmentData['totalTratamiento'] as num?)?.toDouble() ??
        (paymentData['totalTratamiento'] as num?)?.toDouble() ??
        0;
    final targetSaldo = (treatmentData['saldoPendiente'] as num?)?.toDouble() ??
        (paymentData['saldoPendiente'] as num?)?.toDouble() ??
        0;
    final targetPaid = (targetTotal - targetSaldo).clamp(0, double.infinity).toDouble();
    final fechaProximoPago = _parseNullableDate(paymentData['fechaProximoPago']);

    if (monto > targetSaldo) {
      throw Exception('PAYMENT_EXCEEDS_BALANCE');
    }

    final nuevoSaldo = targetSaldo - monto;
    final nuevoPagado = targetPaid + monto;

    final nuevoEstado = PaymentModel.calcularEstado(
      saldoPendiente: nuevoSaldo,
      fechaProximoPago: fechaProximoPago,
    );

    final txRef = _db.collection(FirestorePaths.transactions(patientId)).doc();
    final batch = _db.batch();

    batch.set(txRef, {
      'id': txRef.id,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': metodo.name,
      'referencia': referencia,
      'registradoPor': registradoPor,
      'notas': notas,
      'reciboUrl': null,
      'payuOrderId': payuOrderId,
      'payuTransactionId': payuTransactionId,
      'treatmentId': treatmentId,
    });

    if (treatmentDoc != null && treatmentDoc.exists) {
      batch.update(treatmentDoc.reference, {
        'saldoPendiente': nuevoSaldo,
        'updatedAt': FieldValue.serverTimestamp(),
        'financialSummary.paidAmount': nuevoPagado,
        'financialSummary.pendingAmount': nuevoSaldo,
      });
    }

    final mirrorsPrimary = treatmentId == null ||
        treatmentId.isEmpty ||
        (treatmentData['isPrimary'] as bool?) == true ||
        (paymentData['treatmentId'] ?? '') == treatmentId;

    if (paymentDoc.exists && mirrorsPrimary) {
      batch.set(paymentRef, {
        'montoPagado': nuevoPagado,
        'saldoPendiente': nuevoSaldo,
        'estado': nuevoEstado.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (treatmentId != null && treatmentId.isNotEmpty) 'treatmentId': treatmentId,
      }, SetOptions(merge: true));

      batch.set(_db.collection(FirestorePaths.patients).doc(patientId), {
        'saldoPendiente': nuevoSaldo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> updateTransactionReceiptUrl({
    required String patientId,
    required String transactionId,
    required String reciboUrl,
  }) async {
    await _db.collection(FirestorePaths.transactions(patientId)).doc(transactionId).update({
      'reciboUrl': reciboUrl,
    });
  }

  Future<void> updateNextPaymentDate(String patientId, DateTime fecha) async {
    final paymentRef = _db.collection(FirestorePaths.payments).doc(patientId);
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
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
