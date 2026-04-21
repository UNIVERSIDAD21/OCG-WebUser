import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/data/models/patient_data_resolution.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/data/services/patient_data_resolution_service.dart';
import '../data/models/patient_treatment.dart';
import '../data/repositories/patient_treatments_repository.dart';

final patientTreatmentsRepositoryProvider =
    Provider<PatientTreatmentsRepository>((ref) {
      return PatientTreatmentsRepository(FirebaseFirestore.instance);
    });

final patientDataResolutionServiceProvider =
    Provider<PatientDataResolutionService>((ref) {
      return const PatientDataResolutionService();
    });

final patientTreatmentsProvider =
    StreamProvider.family<List<PatientTreatment>, String>((ref, patientId) {
      return ref
          .watch(patientTreatmentsRepositoryProvider)
          .watchPatientTreatments(patientId);
    });

class SavePatientTreatmentNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> migrateLegacyPatientIfNeeded({
    required PatientModel patient,
    String createdBy = 'system-migration',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(patientTreatmentsRepositoryProvider)
          .migrateLegacyPatientTreatmentIfNeeded(
            patient: patient,
            createdBy: createdBy,
          );
    });
  }

  Future<void> saveTreatment({
    required String patientId,
    required PatientTreatment treatment,
    String? previousPrimaryId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(patientTreatmentsRepositoryProvider)
          .saveTreatment(
            patientId: patientId,
            treatment: treatment,
            previousPrimaryId: previousPrimaryId,
          );
    });
  }

  Future<void> setPrimaryTreatment({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(patientTreatmentsRepositoryProvider)
          .setPrimaryTreatment(patientId: patientId, treatment: treatment),
    );
  }

  Future<void> updateTreatmentStatus({
    required String patientId,
    required PatientTreatment treatment,
    required String newStatus,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(patientTreatmentsRepositoryProvider)
          .updateTreatmentStatus(
            patientId: patientId,
            treatment: treatment,
            newStatus: newStatus,
          ),
    );
  }
}

final savePatientTreatmentProvider =
    AsyncNotifierProvider.autoDispose<SavePatientTreatmentNotifier, void>(
      SavePatientTreatmentNotifier.new,
    );

final effectivePatientTreatmentsProvider =
    Provider.family<
      List<PatientTreatment>,
      ({String patientId, PatientModel patient})
    >((ref, args) {
      final asyncTreatments = ref.watch(
        patientTreatmentsProvider(args.patientId),
      );
      final remote =
          asyncTreatments.asData?.value ?? const <PatientTreatment>[];
      final resolved = ref
          .watch(patientDataResolutionServiceProvider)
          .resolve(
            patient: args.patient,
            newTreatments: remote,
            legacyPayment: null,
            treatmentPayments: const [],
            legacyTransactions: const [],
            treatmentTransactions: const [],
          );
      return resolved.treatments;
    });

final patientDataModeProvider =
    Provider.family<
      PatientDataMode,
      ({String patientId, PatientModel patient})
    >((ref, args) {
      final asyncTreatments = ref.watch(
        patientTreatmentsProvider(args.patientId),
      );
      final remote =
          asyncTreatments.asData?.value ?? const <PatientTreatment>[];
      final resolved = ref
          .watch(patientDataResolutionServiceProvider)
          .resolve(
            patient: args.patient,
            newTreatments: remote,
            legacyPayment: null,
            treatmentPayments: const [],
            legacyTransactions: const [],
            treatmentTransactions: const [],
          );
      return resolved.mode;
    });
