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
    required TreatmentStage etapaActual,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
    String? motivoCambio,
    String? diagnosticoBreve,
    String? planSiguienteEtapa,
    String? adjuntosDescripcion,
    DateTime? fechaEfectiva,
  }) async {
    if (nuevaEtapa == etapaActual) {
      throw Exception('STAGE_SAME');
    }

    final notasClean = notas.trim();
    if (notasClean.isNotEmpty && notasClean.length < 10) {
      throw Exception('NOTES_TOO_SHORT');
    }

    final idxAnterior = _stageOrder.indexOf(etapaActual);
    final idxNueva = _stageOrder.indexOf(nuevaEtapa);
    final esRetroceso = idxNueva < idxAnterior;

    final batch = _db.batch();
    final patientRef = _db.collection(FirestorePaths.patients).doc(patientId);
    final historyRef = _db.collection(FirestorePaths.stageHistory(patientId)).doc();

    final entry = StageHistoryEntry(
      id: historyRef.id,
      etapaAnterior: etapaActual,
      etapaNueva: nuevaEtapa,
      esRetroceso: esRetroceso,
      notas: notasClean,
      motivoCambio: _nullableTrim(motivoCambio),
      diagnosticoBreve: _nullableTrim(diagnosticoBreve),
      planSiguienteEtapa: _nullableTrim(planSiguienteEtapa),
      adjuntosDescripcion: _nullableTrim(adjuntosDescripcion),
      fechaEfectiva: fechaEfectiva,
      adminId: adminId,
      fechaCambio: DateTime.now(),
    );

    batch.update(patientRef, {
      'etapaActual': nuevaEtapa.name,
      'updatedAt': Timestamp.now(),
    });
    batch.set(historyRef, entry.toJson());

    await batch.commit();
  }

  String? _nullableTrim(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}
