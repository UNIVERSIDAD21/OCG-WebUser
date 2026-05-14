import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

class StageHistoryEntry {
  const StageHistoryEntry({
    required this.id,
    required this.patientId,
    required this.treatmentId,
    required this.etapaAnterior,
    required this.etapaNueva,
    required this.esRetroceso,
    required this.notas,
    this.motivoCambio,
    this.diagnosticoBreve,
    this.planSiguienteEtapa,
    this.adjuntosDescripcion,
    this.consultationId,
    this.signatureUrl,
    this.fechaEfectiva,
    required this.adminId,
    required this.fechaCambio,
    this.status = 'completed',
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String patientId;
  final String treatmentId;
  final TreatmentStage etapaAnterior;
  final TreatmentStage etapaNueva;
  final bool esRetroceso;

  final String notas;
  final String? motivoCambio;
  final String? diagnosticoBreve;
  final String? planSiguienteEtapa;
  final String? adjuntosDescripcion;
  final String? consultationId;
  final String? signatureUrl;
  final DateTime? fechaEfectiva;

  final String adminId;
  final DateTime fechaCambio;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;

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
      patientId: (json['patientId'] ?? '').toString(),
      treatmentId: (json['treatmentId'] ?? '').toString(),
      etapaAnterior: _parseStage(json['etapaAnterior']),
      etapaNueva: _parseStage(json['etapaNueva']),
      esRetroceso: (json['esRetroceso'] as bool?) ?? false,
      notas: (json['notes'] ?? json['notas'] ?? '').toString(),
      motivoCambio: json['motivoCambio']?.toString(),
      diagnosticoBreve: json['diagnosticoBreve']?.toString(),
      planSiguienteEtapa: json['planSiguienteEtapa']?.toString(),
      adjuntosDescripcion: json['adjuntosDescripcion']?.toString(),
      consultationId: json['consultationId']?.toString(),
      signatureUrl: json['signatureUrl']?.toString(),
      fechaEfectiva: _parseNullableDate(json['fechaEfectiva']),
      adminId: (json['createdBy'] ?? json['adminId'] ?? '').toString(),
      fechaCambio: _parseDate(
        json['createdAt'] ?? json['fechaCambio'],
        DateTime.now(),
      ),
      status: (json['status'] ?? 'completed').toString(),
      startedAt: _parseNullableDate(json['startedAt']),
      completedAt: _parseNullableDate(json['completedAt']),
    );
  }

  StageHistoryEntry copyWith({
    String? id,
    String? patientId,
    String? treatmentId,
    TreatmentStage? etapaAnterior,
    TreatmentStage? etapaNueva,
    bool? esRetroceso,
    String? notas,
    String? motivoCambio,
    String? diagnosticoBreve,
    String? planSiguienteEtapa,
    String? adjuntosDescripcion,
    String? consultationId,
    String? signatureUrl,
    DateTime? fechaEfectiva,
    String? adminId,
    DateTime? fechaCambio,
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return StageHistoryEntry(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      treatmentId: treatmentId ?? this.treatmentId,
      etapaAnterior: etapaAnterior ?? this.etapaAnterior,
      etapaNueva: etapaNueva ?? this.etapaNueva,
      esRetroceso: esRetroceso ?? this.esRetroceso,
      notas: notas ?? this.notas,
      motivoCambio: motivoCambio ?? this.motivoCambio,
      diagnosticoBreve: diagnosticoBreve ?? this.diagnosticoBreve,
      planSiguienteEtapa: planSiguienteEtapa ?? this.planSiguienteEtapa,
      adjuntosDescripcion: adjuntosDescripcion ?? this.adjuntosDescripcion,
      consultationId: consultationId ?? this.consultationId,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      fechaEfectiva: fechaEfectiva ?? this.fechaEfectiva,
      adminId: adminId ?? this.adminId,
      fechaCambio: fechaCambio ?? this.fechaCambio,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get stageName => stageNames[etapaNueva] ?? etapaNueva.name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'treatmentId': treatmentId,
    'stageName': stageName,
    'status': status,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'createdAt': Timestamp.fromDate(fechaCambio),
    'createdBy': adminId,
    // Compatibilidad temporal
    'etapaAnterior': etapaAnterior.name,
    'etapaNueva': etapaNueva.name,
    'esRetroceso': esRetroceso,
    'notes': notas,
    'notas': notas,
    'motivoCambio': motivoCambio,
    'diagnosticoBreve': diagnosticoBreve,
    'planSiguienteEtapa': planSiguienteEtapa,
    'adjuntosDescripcion': adjuntosDescripcion,
    'consultationId': consultationId,
    'signatureUrl': signatureUrl,
    'fechaEfectiva': fechaEfectiva == null
        ? null
        : Timestamp.fromDate(fechaEfectiva!),
    'adminId': adminId,
    'fechaCambio': Timestamp.fromDate(fechaCambio),
  };
}
