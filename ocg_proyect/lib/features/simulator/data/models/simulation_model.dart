import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

enum SimulationMode {
  mock,
  manualDoctora,
}

enum SimulationStatus {
  draft,
  ready,
  shared,
  archived,
}

class SimulationModel {
  const SimulationModel({
    required this.id,
    required this.patientId,
    required this.originalUrl,
    required this.resultUrl,
    required this.mode,
    required this.compartidaConPaciente,
    required this.createdAt,
    required this.updatedAt,
    required this.creadoPor,
    required this.treatmentType,
    required this.status,
    required this.notes,
    required this.mlKitUsed,
    required this.detectedRegion,
    required this.promptMetadata,
  });

  final String id;
  final String patientId;
  final String originalUrl;
  final String? resultUrl;
  final SimulationMode mode;
  final bool compartidaConPaciente;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String creadoPor;
  final TreatmentType? treatmentType;
  final SimulationStatus status;
  final String? notes;
  final bool mlKitUsed;
  final Map<String, dynamic>? detectedRegion;
  final Map<String, dynamic>? promptMetadata;

  factory SimulationModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final modeRaw = (json['mode'] ?? '').toString();
    final statusRaw = (json['status'] ?? '').toString();
    final treatmentRaw = (json['treatmentType'] ?? '').toString();

    return SimulationModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      originalUrl: (json['originalUrl'] ?? '').toString(),
      resultUrl: json['resultUrl']?.toString(),
      mode: SimulationMode.values.firstWhere(
        (e) => e.name == modeRaw,
        orElse: () => SimulationMode.manualDoctora,
      ),
      compartidaConPaciente: (json['compartidaConPaciente'] as bool?) ?? false,
      createdAt: _parseDate(json['createdAt'], fallback: now),
      updatedAt: _parseNullableDate(json['updatedAt']),
      creadoPor: (json['creadoPor'] ?? '').toString(),
      treatmentType: _parseTreatmentType(treatmentRaw),
      status: SimulationStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => SimulationStatus.draft,
      ),
      notes: json['notes']?.toString(),
      mlKitUsed: (json['mlKitUsed'] as bool?) ?? false,
      detectedRegion: _asMap(json['detectedRegion']),
      promptMetadata: _asMap(json['promptMetadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'originalUrl': originalUrl,
      'resultUrl': resultUrl,
      'mode': mode.name,
      'compartidaConPaciente': compartidaConPaciente,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'creadoPor': creadoPor,
      'treatmentType': treatmentType?.name,
      'status': status.name,
      'notes': notes,
      'mlKitUsed': mlKitUsed,
      'detectedRegion': detectedRegion,
      'promptMetadata': promptMetadata,
    };
  }

  SimulationModel copyWith({
    String? id,
    String? patientId,
    String? originalUrl,
    String? resultUrl,
    bool clearResultUrl = false,
    SimulationMode? mode,
    bool? compartidaConPaciente,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? creadoPor,
    TreatmentType? treatmentType,
    bool clearTreatmentType = false,
    SimulationStatus? status,
    String? notes,
    bool clearNotes = false,
    bool? mlKitUsed,
    Map<String, dynamic>? detectedRegion,
    bool clearDetectedRegion = false,
    Map<String, dynamic>? promptMetadata,
    bool clearPromptMetadata = false,
  }) {
    return SimulationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      originalUrl: originalUrl ?? this.originalUrl,
      resultUrl: clearResultUrl ? null : (resultUrl ?? this.resultUrl),
      mode: mode ?? this.mode,
      compartidaConPaciente: compartidaConPaciente ?? this.compartidaConPaciente,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      creadoPor: creadoPor ?? this.creadoPor,
      treatmentType: clearTreatmentType ? null : (treatmentType ?? this.treatmentType),
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      mlKitUsed: mlKitUsed ?? this.mlKitUsed,
      detectedRegion: clearDetectedRegion ? null : (detectedRegion ?? this.detectedRegion),
      promptMetadata: clearPromptMetadata ? null : (promptMetadata ?? this.promptMetadata),
    );
  }

  static DateTime _parseDate(dynamic value, {required DateTime fallback}) {
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

  static TreatmentType? _parseTreatmentType(String raw) {
    if (raw.isEmpty) return null;
    for (final type in TreatmentType.values) {
      if (type.name == raw) return type;
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
