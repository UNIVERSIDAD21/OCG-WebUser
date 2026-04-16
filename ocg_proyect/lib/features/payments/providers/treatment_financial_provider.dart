import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../treatment/data/models/patient_treatment.dart';
import '../data/models/financial_item_model.dart';
import '../data/repositories/treatment_financial_repository.dart';

final treatmentFinancialRepositoryProvider = Provider<TreatmentFinancialRepository>((ref) {
  return TreatmentFinancialRepository(FirebaseFirestore.instance);
});

final treatmentFinancialItemsProvider =
    StreamProvider.family<List<FinancialItemModel>, ({String patientId, String treatmentId})>((ref, args) {
  return ref
      .watch(treatmentFinancialRepositoryProvider)
      .watchFinancialItems(args.patientId, args.treatmentId);
});

class SaveTreatmentFinancialItemsNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> replaceItems({
    required String patientId,
    required PatientTreatment treatment,
    required List<FinancialItemModel> items,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(treatmentFinancialRepositoryProvider).replaceFinancialItems(
          patientId: patientId,
          treatment: treatment,
          items: items,
        ));
  }
}

final saveTreatmentFinancialItemsProvider =
    AsyncNotifierProvider.autoDispose<SaveTreatmentFinancialItemsNotifier, void>(
  SaveTreatmentFinancialItemsNotifier.new,
);
