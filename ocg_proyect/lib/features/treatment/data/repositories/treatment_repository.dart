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

  Stream<List<StageHistoryEntry>> watchTreatmentStageHistory(
    String patientId,
    String treatmentId,
  ) {
    return _db
        .collection(FirestorePaths.treatmentStageHistory(patientId, treatmentId))
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
    String? treatmentId,
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
    if (notasClean.length < 10) {
      throw Exception('NOTES_TOO_SHORT');
    }

    final idxAnterior = _stageOrder.indexOf(etapaActual);
    final idxNueva = _stageOrder.indexOf(nuevaEtapa);
    final esRetroceso = idxNueva < idxAnterior;
    if (esRetroceso) {
      throw Exception('STAGE_REGRESSION');
    }

    final batch = _db.batch();
    final patientRef = _db.collection(FirestorePaths.patients).doc(patientId);
    final historyRef = _db.collection(FirestorePaths.stageHistory(patientId)).doc();

    final now = DateTime.now();
    final entry = StageHistoryEntry(
      id: historyRef.id,
      patientId: patientId,
      treatmentId: treatmentId ?? '',
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
      fechaCambio: now,
      status: 'completed',
      startedAt: fechaEfectiva ?? now,
      completedAt: now,
    );

    if (treatmentId == null || treatmentId.isEmpty) {
      batch.update(patientRef, {
        'etapaActual': nuevaEtapa.name,
        'updatedAt': Timestamp.now(),
      });
      batch.set(historyRef, entry.toJson());
      await batch.commit();
      return;
    }

    final treatmentRef = _db.doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId));
    final treatmentHistoryRef =
        _db.collection(FirestorePaths.treatmentStageHistory(patientId, treatmentId)).doc();
    final treatmentSnapshot = await treatmentRef.get();
    final treatmentData = treatmentSnapshot.data() ?? <String, dynamic>{};
    final isPrimary = (treatmentData['isPrimary'] as bool?) ?? false;

    batch.update(treatmentRef, {
      'etapaActual': nuevaEtapa.name,
      'currentStageId': nuevaEtapa.name,
      'currentStageName': stageNames[nuevaEtapa] ?? nuevaEtapa.name,
      'updatedAt': Timestamp.now(),
    });
    batch.set(
      treatmentHistoryRef,
      entry.copyWith(
        id: treatmentHistoryRef.id,
        treatmentId: treatmentId,
      ).toJson(),
    );

    if (isPrimary) {
      batch.update(patientRef, {
        'etapaActual': nuevaEtapa.name,
        'updatedAt': Timestamp.now(),
      });
      batch.set(historyRef, entry.toJson());
    }

    await batch.commit();
  }

  String? _nullableTrim(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}
