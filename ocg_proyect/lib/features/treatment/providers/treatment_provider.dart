import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/data/models/patient_model.dart';
import '../data/models/stage_history_entry.dart';
import '../data/repositories/treatment_repository.dart';

final treatmentRepositoryProvider = Provider<TreatmentRepository>((ref) {
  return TreatmentRepository(FirebaseFirestore.instance);
});

final stageHistoryProvider = StreamProvider.family<List<StageHistoryEntry>, String>(
  (ref, patientId) => ref.watch(treatmentRepositoryProvider).watchStageHistory(patientId),
);

class UpdateStageNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> updateStage({
    required String patientId,
    required TreatmentStage etapaAnterior,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(treatmentRepositoryProvider).updateStage(
        patientId: patientId,
        etapaAnterior: etapaAnterior,
        nuevaEtapa: nuevaEtapa,
        notas: notas,
        adminId: adminId,
      ),
    );
  }
}

final updateStageProvider = AsyncNotifierProvider<UpdateStageNotifier, void>(
  UpdateStageNotifier.new,
);
