import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../services/payu_service.dart';
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(paymentsRepositoryProvider);

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
              (patientData['numeroDocumento'] ?? patientData['documento'] ?? '').toString();

          await ref.read(pdfReceiptServiceProvider).generateAndUpload(
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
    });
  }
}

final registerPaymentProvider =
    AsyncNotifierProvider.autoDispose<RegisterPaymentNotifier, void>(
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

    state = await AsyncValue.guard(
      () => ref.read(payuServiceProvider).createPaymentSession(
            patientId: patientId,
            monto: monto,
            patientEmail: patientEmail,
            patientName: patientName,
          ),
    );

    if (state.hasError) throw state.error!;
    return state.requireValue!;
  }
}

final initiatePayuPaymentProvider =
    AsyncNotifierProvider.autoDispose<InitiatePayuPaymentNotifier, String?>(
      InitiatePayuPaymentNotifier.new,
    );
