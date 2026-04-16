import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/data/models/patient_model.dart';
import '../../payments/providers/treatment_financial_provider.dart';
import '../data/models/patient_treatment.dart';
import '../data/repositories/patient_treatments_repository.dart';

final patientTreatmentsRepositoryProvider = Provider<PatientTreatmentsRepository>((ref) {
  return PatientTreatmentsRepository(FirebaseFirestore.instance);
});

final patientTreatmentsProvider = StreamProvider.family<List<PatientTreatment>, String>((ref, patientId) {
  return ref.watch(patientTreatmentsRepositoryProvider).watchPatientTreatments(patientId);
});

class SavePatientTreatmentNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> saveTreatment({
    required String patientId,
    required PatientTreatment treatment,
    String? previousPrimaryId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(patientTreatmentsRepositoryProvider).saveTreatment(
            patientId: patientId,
            treatment: treatment,
            previousPrimaryId: previousPrimaryId,
          );
      await ref.read(treatmentFinancialRepositoryProvider).ensureBaseItems(
            patientId: patientId,
            treatment: treatment,
          );
    });
  }

  Future<void> setPrimaryTreatment({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(patientTreatmentsRepositoryProvider).setPrimaryTreatment(
            patientId: patientId,
            treatment: treatment,
          ),
    );
  }

  Future<void> updateTreatmentStatus({
    required String patientId,
    required PatientTreatment treatment,
    required String newStatus,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(patientTreatmentsRepositoryProvider).updateTreatmentStatus(
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

final effectivePatientTreatmentsProvider = Provider.family<List<PatientTreatment>, ({String patientId, PatientModel patient})>((ref, args) {
  final asyncTreatments = ref.watch(patientTreatmentsProvider(args.patientId));
  final remote = asyncTreatments.asData?.value ?? const <PatientTreatment>[];
  if (remote.isNotEmpty) return remote;
  return <PatientTreatment>[PatientTreatment.fromLegacyPatient(args.patient)];
});
