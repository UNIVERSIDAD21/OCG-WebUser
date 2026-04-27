import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../treatment/providers/patient_treatments_provider.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../../patients/data/models/patient_data_resolution.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/data/services/patient_data_resolution_service.dart';
import '../../patients/providers/patients_provider.dart';
import '../services/payu_service.dart';
import '../data/models/admin_payment_overview.dart';
import '../data/models/payment_model.dart';
import '../data/repositories/payments_repository.dart';
import '../services/pdf_receipt_service.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(FirebaseFirestore.instance);
});

final patientDataResolutionServiceProvider =
    Provider<PatientDataResolutionService>((ref) {
      return const PatientDataResolutionService();
    });

final patientPaymentProvider = StreamProvider.family<PaymentModel?, String>((
  ref,
  patientId,
) async* {
  try {
    yield* ref
        .watch(paymentsRepositoryProvider)
        .watchPatientPayments(patientId);
  } catch (error) {
    if (_isPermissionDenied(error)) {
      yield null;
      return;
    }
    rethrow;
  }
});

final treatmentPaymentProvider =
    StreamProvider.family<
      PaymentModel?,
      ({String patientId, String treatmentId})
    >((ref, args) async* {
      try {
        yield* ref
            .watch(paymentsRepositoryProvider)
            .watchPatientPayments(
              args.patientId,
              treatmentId: args.treatmentId,
            );
      } catch (error) {
        if (_isPermissionDenied(error)) {
          yield null;
          return;
        }
        rethrow;
      }
    });

final patientTransactionsProvider =
    StreamProvider.family<
      List<PaymentTransaction>,
      ({String patientId, String? treatmentId})
    >((ref, args) async* {
      try {
        yield* ref
            .watch(paymentsRepositoryProvider)
            .watchTransactions(args.patientId, treatmentId: args.treatmentId);
      } catch (error) {
        if (_isPermissionDenied(error)) {
          yield const <PaymentTransaction>[];
          return;
        }
        rethrow;
      }
    });

final ensureTreatmentPaymentAccountProvider =
    Provider<Future<void> Function(String patientId, PatientTreatment treatment)>(
      (ref) {
        final repository = ref.watch(paymentsRepositoryProvider);
        return (patientId, treatment) => repository.ensureTreatmentPaymentAccount(
          patientId: patientId,
          treatment: treatment,
        );
      },
    );

final effectivePatientPaymentsProvider =
    Provider.family<
      EffectivePatientDataResolution,
      ({String patientId, PatientModel patient})
    >((ref, args) {
      final service = ref.watch(patientDataResolutionServiceProvider);
      final treatments = ref.watch(
        effectivePatientTreatmentsProvider((
          patientId: args.patientId,
          patient: args.patient,
        )),
      );
      final legacyPayment = ref
          .watch(patientPaymentProvider(args.patientId))
          .asData
          ?.value;
      final treatmentPayments = <PaymentModel>[];
      final treatmentTransactions = <PaymentTransaction>[];

      for (final treatment in treatments.where(
        (item) => !item.id.startsWith('legacy-primary-'),
      )) {
        final payment = ref
            .watch(
              treatmentPaymentProvider((
                patientId: args.patientId,
                treatmentId: treatment.id,
              )),
            )
            .asData
            ?.value;
        if (payment != null) {
          treatmentPayments.add(payment);
        }
        final transactions = ref
            .watch(
              patientTransactionsProvider((
                patientId: args.patientId,
                treatmentId: treatment.id,
              )),
            )
            .asData
            ?.value;
        if (transactions != null) {
          treatmentTransactions.addAll(transactions);
        }
      }

      final legacyTransactions =
          ref
              .watch(
                patientTransactionsProvider((
                  patientId: args.patientId,
                  treatmentId: null,
                )),
              )
              .asData
              ?.value ??
          const <PaymentTransaction>[];

      return service.resolve(
        patient: args.patient,
        newTreatments: treatments
            .where((item) => !item.id.startsWith('legacy-primary-'))
            .toList(),
        legacyPayment: legacyPayment,
        treatmentPayments: treatmentPayments,
        legacyTransactions: legacyTransactions,
        treatmentTransactions: treatmentTransactions,
      );
    });

final adminPaymentsOverviewProvider = StreamProvider<AdminPaymentsOverview>((
  ref,
) {
  final controller = StreamController<AdminPaymentsOverview>();
  final repository = ref.watch(paymentsRepositoryProvider);

  List<PatientModel>? patients;
  final paymentByPatient = <String, PaymentModel>{};
  final transactionsByPatient = <String, List<PaymentTransaction>>{};
  final detailSubs = <StreamSubscription<dynamic>>[];
  var detailGeneration = 0;

  void emitIfReady() {
    if (patients == null) return;

    final entries =
        patients!.map((patient) {
          final payment =
              paymentByPatient[patient.id] ?? _paymentFromPatient(patient);
          final transactions =
              transactionsByPatient[patient.id] ?? const <PaymentTransaction>[];
          return AdminPaymentEntry(
            patient: patient,
            payment: payment,
            latestTransaction: transactions.isEmpty ? null : transactions.first,
          );
        }).toList()..sort(
          (a, b) => a.patient.nombre.toLowerCase().compareTo(
            b.patient.nombre.toLowerCase(),
          ),
        );

    final now = DateTime.now();
    final transactionsThisMonth = transactionsByPatient.values
        .expand((items) => items)
        .where(
          (transaction) =>
              transaction.fecha.year == now.year &&
              transaction.fecha.month == now.month,
        )
        .length;

    final totalDebt = entries.fold<double>(
      0,
      (total, entry) => total + entry.saldoPendiente,
    );

    final history =
        patients!.expand((patient) {
          final payment =
              paymentByPatient[patient.id] ?? _paymentFromPatient(patient);
          final transactions =
              transactionsByPatient[patient.id] ?? const <PaymentTransaction>[];
          return transactions
              .where((transaction) => transaction.monto > 0)
              .map(
                (transaction) => AdminPaymentHistoryItem(
                  patient: patient,
                  payment: payment,
                  transaction: transaction,
                ),
              );
        }).toList()..sort(
          (a, b) => b.transaction.fecha.compareTo(a.transaction.fecha),
        );

    controller.add(
      AdminPaymentsOverview(
        entries: entries,
        totalDebt: totalDebt,
        transactionsThisMonth: transactionsThisMonth,
        history: history,
      ),
    );
  }

  Future<void> resetDetailSubscriptions(List<PatientModel> nextPatients) async {
    detailGeneration++;
    final generation = detailGeneration;

    for (final sub in detailSubs) {
      await sub.cancel();
    }
    detailSubs.clear();
    paymentByPatient.clear();
    transactionsByPatient.clear();

    for (final patient in nextPatients) {
      final patientId = patient.id;

      final paymentSub = repository
          .watchPatientPayments(patientId)
          .listen(
            (payment) {
              if (generation != detailGeneration) return;
              if (payment == null) {
                paymentByPatient.remove(patientId);
              } else {
                paymentByPatient[patientId] = payment;
              }
              emitIfReady();
            },
            onError: (error) {
              if (generation != detailGeneration) return;
              if (_isPermissionDenied(error)) {
                paymentByPatient.remove(patientId);
                emitIfReady();
                return;
              }
              controller.addError(error);
            },
          );
      detailSubs.add(paymentSub);

      final txSub = repository
          .watchTransactions(patientId)
          .listen(
            (transactions) {
              if (generation != detailGeneration) return;
              transactionsByPatient[patientId] = transactions;
              emitIfReady();
            },
            onError: (error) {
              if (generation != detailGeneration) return;
              if (_isPermissionDenied(error)) {
                transactionsByPatient[patientId] = const <PaymentTransaction>[];
                emitIfReady();
                return;
              }
              controller.addError(error);
            },
          );
      detailSubs.add(txSub);
    }

    emitIfReady();
  }

  final patientsSub = ref
      .watch(patientsRepositoryProvider)
      .watchAllPatients()
      .listen((value) {
        patients = value;
        resetDetailSubscriptions(value);
      }, onError: controller.addError);

  ref.onDispose(() async {
    detailGeneration++;
    await patientsSub.cancel();
    for (final sub in detailSubs) {
      await sub.cancel();
    }
    await controller.close();
  });

  return controller.stream;
});

PaymentModel _paymentFromPatient(PatientModel patient) {
  final now = DateTime.now();
  return PaymentModel(
    id: patient.id,
    patientId: patient.id,
    totalTratamiento: 0,
    montoPagado: 0,
    saldoPendiente: 0,
    fechaProximoPago: patient.fechaProximoPago,
    estado: PaymentStatus.pendiente,
    createdAt: patient.createdAt ?? now,
    updatedAt: patient.updatedAt ?? now,
  );
}

bool _isPermissionDenied(Object error) {
  return error is FirebaseException &&
      error.plugin == 'cloud_firestore' &&
      error.code == 'permission-denied';
}

class RegisterPaymentNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> registerManual({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? treatmentId,
    String? referencia,
    String? notas,
  }) async {
    final repository = ref.read(paymentsRepositoryProvider);
    final pdfService = ref.read(pdfReceiptServiceProvider);
    final authService = ref.read(authServiceProvider);
    final currentUser = ref.read(authStateProvider).asData?.value;
    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      await authService.bootstrapAdminByEmailIfAllowed(email);
    }

    await repository.registerManualPayment(
      patientId: patientId,
      monto: monto,
      metodo: metodo,
      adminId: adminId,
      treatmentId: treatmentId,
      referencia: referencia,
      notas: notas,
    );

    try {
      final tx = await repository.getLatestTransaction(
        patientId,
        treatmentId: treatmentId,
      );
      final summary = await repository.getPatientPayment(
        patientId,
        treatmentId: treatmentId,
      );
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
          treatmentId: treatmentId,
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
