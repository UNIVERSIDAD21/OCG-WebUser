import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../patients/data/models/patient_model.dart';
import '../models/stage_history_entry.dart';

class TreatmentRepository {
  TreatmentRepository(this._db);

  final FirebaseFirestore _db;

  static const _stageOrder = TreatmentStage.values;

  Stream<List<StageHistoryEntry>> watchStageHistory(String patientId) {
    return _db
        .collection(FirestorePaths.stageHistory(patientId))
        .orderBy('fechaCambio', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => StageHistoryEntry.fromJson(d.data())).toList());
  }

  Future<void> updateStage({
    required String patientId,
    required TreatmentStage etapaAnterior,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
  }) async {
    final idxAnterior = _stageOrder.indexOf(etapaAnterior);
    final idxNueva = _stageOrder.indexOf(nuevaEtapa);

    if (idxNueva <= idxAnterior) {
      throw Exception('STAGE_REGRESSION');
    }

    final batch = _db.batch();
    final patientRef = _db.collection(FirestorePaths.patients).doc(patientId);
    final historyRef = _db.collection(FirestorePaths.stageHistory(patientId)).doc();

    final entry = StageHistoryEntry(
      id: historyRef.id,
      etapaAnterior: etapaAnterior,
      etapaNueva: nuevaEtapa,
      notas: notas,
      adminId: adminId,
      fechaCambio: DateTime.now(),
    );

    batch.update(patientRef, {
      'etapaActual': nuevaEtapa.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(historyRef, entry.toJson());

    await batch.commit();
  }
}
