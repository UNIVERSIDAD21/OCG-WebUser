import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

class StageHistoryEntry {
  const StageHistoryEntry({
    required this.id,
    required this.etapaAnterior,
    required this.etapaNueva,
    required this.esRetroceso,
    required this.notas,
    this.motivoCambio,
    this.diagnosticoBreve,
    this.planSiguienteEtapa,
    this.adjuntosDescripcion,
    this.fechaEfectiva,
    required this.adminId,
    required this.fechaCambio,
  });

  final String id;
  final TreatmentStage etapaAnterior;
  final TreatmentStage etapaNueva;
  final bool esRetroceso;

  final String notas;
  final String? motivoCambio;
  final String? diagnosticoBreve;
  final String? planSiguienteEtapa;
  final String? adjuntosDescripcion;
  final DateTime? fechaEfectiva;

  final String adminId;
  final DateTime fechaCambio;

  static DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static TreatmentStage _parseStage(dynamic raw) {
    final value = (raw ?? '').toString();
    const legacyMap = {
      'diagnostico': TreatmentStage.valoracionInicial,
      'planificacion': TreatmentStage.estudioPlaneacion,
      'seguimientoActivo': TreatmentStage.controles,
      'ajusteFinal': TreatmentStage.controles,
    };
    if (legacyMap.containsKey(value)) return legacyMap[value]!;
    return TreatmentStage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TreatmentStage.valoracionInicial,
    );
  }

  factory StageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StageHistoryEntry(
      id: (json['id'] ?? '').toString(),
      etapaAnterior: _parseStage(json['etapaAnterior']),
      etapaNueva: _parseStage(json['etapaNueva']),
      esRetroceso: (json['esRetroceso'] as bool?) ?? false,
      notas: (json['notas'] ?? '').toString(),
      motivoCambio: json['motivoCambio']?.toString(),
      diagnosticoBreve: json['diagnosticoBreve']?.toString(),
      planSiguienteEtapa: json['planSiguienteEtapa']?.toString(),
      adjuntosDescripcion: json['adjuntosDescripcion']?.toString(),
      fechaEfectiva: _parseNullableDate(json['fechaEfectiva']),
      adminId: (json['adminId'] ?? '').toString(),
      fechaCambio: _parseDate(json['fechaCambio'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'etapaAnterior': etapaAnterior.name,
        'etapaNueva': etapaNueva.name,
        'esRetroceso': esRetroceso,
        'notas': notas,
        'motivoCambio': motivoCambio,
        'diagnosticoBreve': diagnosticoBreve,
        'planSiguienteEtapa': planSiguienteEtapa,
        'adjuntosDescripcion': adjuntosDescripcion,
        'fechaEfectiva': fechaEfectiva == null ? null : Timestamp.fromDate(fechaEfectiva!),
        'adminId': adminId,
        'fechaCambio': Timestamp.now(),
      };
}
