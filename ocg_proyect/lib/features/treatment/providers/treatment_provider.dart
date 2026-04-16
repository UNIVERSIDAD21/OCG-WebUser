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

typedef TreatmentStageHistoryArgs = ({String patientId, String treatmentId});

final treatmentStageHistoryProvider =
    StreamProvider.family<List<StageHistoryEntry>, TreatmentStageHistoryArgs>(
  (ref, args) => ref
      .watch(treatmentRepositoryProvider)
      .watchTreatmentStageHistory(args.patientId, args.treatmentId),
);

class UpdateStageNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> updateStage({
    required String patientId,
    required TreatmentStage etapaActual,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
    String? treatmentId,
    String? motivoCambio,
    String? diagnosticoBreve,
    String? planSiguienteEtapa,
    String? adjuntosDescripcion,
    DateTime? fechaEfectiva,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(treatmentRepositoryProvider).updateStage(
            patientId: patientId,
            etapaActual: etapaActual,
            nuevaEtapa: nuevaEtapa,
            notas: notas,
            adminId: adminId,
            treatmentId: treatmentId,
            motivoCambio: motivoCambio,
            diagnosticoBreve: diagnosticoBreve,
            planSiguienteEtapa: planSiguienteEtapa,
            adjuntosDescripcion: adjuntosDescripcion,
            fechaEfectiva: fechaEfectiva,
          ),
    );
  }
}

final updateStageProvider = AsyncNotifierProvider.autoDispose<UpdateStageNotifier, void>(
  UpdateStageNotifier.new,
);
