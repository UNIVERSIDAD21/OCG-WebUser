import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

class StageHistoryEntry {
  const StageHistoryEntry({
    required this.id,
    required this.etapaAnterior,
    required this.etapaNueva,
    required this.notas,
    required this.adminId,
    required this.fechaCambio,
  });

  final String id;
  final TreatmentStage etapaAnterior;
  final TreatmentStage etapaNueva;
  final String notas;
  final String adminId;
  final DateTime fechaCambio;

  factory StageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StageHistoryEntry(
      id: json['id'] as String,
      etapaAnterior: TreatmentStage.values.firstWhere(
        (e) => e.name == json['etapaAnterior'],
        orElse: () => TreatmentStage.diagnostico,
      ),
      etapaNueva: TreatmentStage.values.firstWhere(
        (e) => e.name == json['etapaNueva'],
        orElse: () => TreatmentStage.diagnostico,
      ),
      notas: json['notas'] as String,
      adminId: json['adminId'] as String,
      fechaCambio: (json['fechaCambio'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'etapaAnterior': etapaAnterior.name,
    'etapaNueva': etapaNueva.name,
    'notas': notas,
    'adminId': adminId,
    'fechaCambio': FieldValue.serverTimestamp(),
  };
}
