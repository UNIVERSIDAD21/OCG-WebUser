import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../services/payu_service.dart';
import '../data/models/admin_payment_overview.dart';
import '../data/models/payment_model.dart';
import '../data/repositories/payments_repository.dart';
import '../services/pdf_receipt_service.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(FirebaseFirestore.instance);
});

final patientPaymentProvider = StreamProvider.family<PaymentModel?, String>((
  ref,
  patientId,
) {
  return ref.watch(paymentsRepositoryProvider).watchPatientPayments(patientId);
});

final patientTransactionsProvider =
    StreamProvider.family<List<PaymentTransaction>, String>((ref, patientId) {
      return ref.watch(paymentsRepositoryProvider).watchTransactions(patientId);
    });

final adminPaymentsOverviewProvider = StreamProvider<AdminPaymentsOverview>((
  ref,
) {
  final controller = StreamController<AdminPaymentsOverview>();

  List<PatientModel>? patients;
  List<PaymentModel>? payments;
  List<_PatientTransaction>? transactions;

  void emitIfReady() {
    if (patients == null || payments == null || transactions == null) {
      return;
    }

    final patientById = {for (final patient in patients!) patient.id: patient};
    final paymentById = {
      for (final payment in payments!) payment.patientId: payment,
    };

    final latestTransactionByPatient = <String, PaymentTransaction>{};
    for (final item in transactions!) {
      latestTransactionByPatient.putIfAbsent(
        item.patientId,
        () => item.transaction,
      );
    }

    final entries =
        patientById.values.map((patient) {
          final payment =
              paymentById[patient.id] ?? _paymentFromPatient(patient);
          return AdminPaymentEntry(
            patient: patient,
            payment: payment,
            latestTransaction: latestTransactionByPatient[patient.id],
          );
        }).toList()..sort(
          (a, b) => a.patient.nombre.toLowerCase().compareTo(
            b.patient.nombre.toLowerCase(),
          ),
        );

    final now = DateTime.now();
    final transactionsThisMonth = transactions!
        .where(
          (item) =>
              item.transaction.fecha.year == now.year &&
              item.transaction.fecha.month == now.month,
        )
        .length;

    final totalDebt = entries.fold<double>(
      0,
      (total, entry) => total + entry.saldoPendiente,
    );

    controller.add(
      AdminPaymentsOverview(
        entries: entries,
        totalDebt: totalDebt,
        transactionsThisMonth: transactionsThisMonth,
      ),
    );
  }

  final patientsSub = ref
      .watch(patientsRepositoryProvider)
      .watchAllPatients()
      .listen((value) {
        patients = value;
        emitIfReady();
      }, onError: controller.addError);

  final paymentsSub = FirebaseFirestore.instance
      .collection(FirestorePaths.payments)
      .snapshots()
      .listen((snap) {
        payments = snap.docs
            .map((doc) => PaymentModel.fromJson(doc.data()))
            .toList();
        emitIfReady();
      }, onError: controller.addError);

  final transactionsSub = FirebaseFirestore.instance
      .collectionGroup('transactions')
      .orderBy('fecha', descending: true)
      .snapshots()
      .listen((snap) {
        transactions = snap.docs
            .map((doc) {
              final patientId = doc.reference.parent.parent?.id;
              if (patientId == null || patientId.isEmpty) {
                return null;
              }
              return _PatientTransaction(
                patientId: patientId,
                transaction: PaymentTransaction.fromJson(doc.data()),
              );
            })
            .whereType<_PatientTransaction>()
            .toList();
        emitIfReady();
      }, onError: controller.addError);

  ref.onDispose(() async {
    await patientsSub.cancel();
    await paymentsSub.cancel();
    await transactionsSub.cancel();
    await controller.close();
  });

  return controller.stream;
});

PaymentModel _paymentFromPatient(PatientModel patient) {
  final now = DateTime.now();
  return PaymentModel(
    id: patient.id,
    patientId: patient.id,
    totalTratamiento: patient.totalTratamiento,
    montoPagado: patient.totalPagado,
    saldoPendiente: patient.saldoPendiente,
    fechaProximoPago: patient.fechaProximoPago,
    estado: PaymentModel.calcularEstado(
      saldoPendiente: patient.saldoPendiente,
      fechaProximoPago: patient.fechaProximoPago,
      now: now,
    ),
    createdAt: patient.createdAt ?? now,
    updatedAt: patient.updatedAt ?? now,
  );
}

class _PatientTransaction {
  const _PatientTransaction({
    required this.patientId,
    required this.transaction,
  });

  final String patientId;
  final PaymentTransaction transaction;
}

class RegisterPaymentNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> registerManual({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  }) async {
    final repository = ref.read(paymentsRepositoryProvider);
    final pdfService = ref.read(pdfReceiptServiceProvider);

    await repository.registerManualPayment(
      patientId: patientId,
      monto: monto,
      metodo: metodo,
      adminId: adminId,
      referencia: referencia,
      notas: notas,
    );

    try {
      final tx = await repository.getLatestTransaction(patientId);
      final summary = await repository.getPatientPayment(patientId);
      final patientDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.patients)
          .doc(patientId)
          .get();

      if (tx != null && summary != null && patientDoc.exists) {
        final patientData = patientDoc.data() ?? <String, dynamic>{};
        final patientName = (patientData['nombre'] ?? '').toString();
        final patientDocument =
            (patientData['numeroDocumento'] ?? patientData['documento'] ?? '')
                .toString();

        await pdfService.generateAndUpload(
          patientId: patientId,
          transactionId: tx.id,
          transaction: tx,
          paymentSummary: summary,
          patientName: patientName,
          patientDocument: patientDocument,
        );
      }
    } catch (_) {
      // El pago ya fue registrado; no revertir por fallo en PDF.
    }
  }
}

final registerPaymentProvider =
    AsyncNotifierProvider<RegisterPaymentNotifier, void>(
      RegisterPaymentNotifier.new,
    );

final payuServiceProvider = Provider<PayuService>((ref) => PayuService());

final pdfReceiptServiceProvider = Provider<PdfReceiptService>((ref) {
  return PdfReceiptService(ref.watch(paymentsRepositoryProvider));
});

class InitiatePayuPaymentNotifier extends AsyncNotifier<String?> {
  @override
  String? build() => null;

  Future<String> initiate({
    required String patientId,
    required double monto,
    required String patientEmail,
    required String patientName,
  }) async {
    state = const AsyncLoading();

    final guarded = await AsyncValue.guard(
      () => ref
          .read(payuServiceProvider)
          .createPaymentSession(
            patientId: patientId,
            monto: monto,
            patientEmail: patientEmail,
            patientName: patientName,
          ),
    );

    if (!ref.mounted) {
      throw Exception('PROVIDER_DISPOSED');
    }

    state = guarded;
    if (state.hasError) throw state.error!;
    return state.requireValue!;
  }
}

final initiatePayuPaymentProvider =
    AsyncNotifierProvider.autoDispose<InitiatePayuPaymentNotifier, String?>(
      InitiatePayuPaymentNotifier.new,
    );
