import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api/payu_service.dart';
import '../data/models/payment_model.dart';
import '../data/repositories/payments_repository.dart';

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
    state = await AsyncValue.guard(
      () => ref.read(paymentsRepositoryProvider).registerManualPayment(
            patientId: patientId,
            monto: monto,
            metodo: metodo,
            adminId: adminId,
            referencia: referencia,
            notas: notas,
          ),
    );
  }
}

final registerPaymentProvider =
    AsyncNotifierProvider.autoDispose<RegisterPaymentNotifier, void>(
      RegisterPaymentNotifier.new,
    );

final payuServiceProvider = Provider<PayuService>((ref) => PayuService());

class InitiatePayuPaymentNotifier extends AsyncNotifier<String?> {
  @override
  String? build() => null;

  Future<String> initiate({
    required String patientId,
    required double monto,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      ref.read(payuServiceProvider); // stub: integración real en Prompt 07
      return 'https://payu-placeholder.ocg.local/checkout?patientId=$patientId&monto=$monto';
    });

    return state.requireValue ??
        'https://payu-placeholder.ocg.local/checkout?patientId=$patientId&monto=$monto';
  }
}

final initiatePayuPaymentProvider =
    AsyncNotifierProvider.autoDispose<InitiatePayuPaymentNotifier, String?>(
      InitiatePayuPaymentNotifier.new,
    );
