import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

enum SimulationStatus {
  draft,
  generating,
  ready,
  shared,
  failed,
  archived,
}

class SimulationModel {
  const SimulationModel({
    required this.id,
    required this.patientId,
    required this.originalPath,
    required this.resultPath,
    required this.compartidaConPaciente,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.treatmentType,
    required this.status,
    required this.notes,
    required this.generationProvider,
    required this.modelUsed,
    required this.attemptCount,
    required this.errorMessage,
    required this.generatedAt,
    required this.promptUsed,
    required this.promptVersion,
    required this.mlKitUsed,
    required this.detectedRegion,
    required this.promptMetadata,
    required this.fechaCompartida,
  });

  final String id;
  final String patientId;
  final String originalPath;
  final String? resultPath;
  final bool compartidaConPaciente;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final TreatmentType? treatmentType;
  final SimulationStatus status;
  final String? notes;
  final String generationProvider;
  final String modelUsed;
  final int attemptCount;
  final String? errorMessage;
  final DateTime? generatedAt;
  final String? promptUsed;
  final String? promptVersion;
  final bool mlKitUsed;
  final Map<String, dynamic>? detectedRegion;
  final Map<String, dynamic>? promptMetadata;
  final DateTime? fechaCompartida;

  String get originalUrl => originalPath;
  String? get resultUrl => resultPath;

  factory SimulationModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final statusRaw = (json['status'] ?? '').toString();
    final treatmentRaw = (json['treatmentType'] ?? '').toString();
    final legacyModeRaw = (json['mode'] ?? '').toString();
    final originalPath = _firstNonEmpty(
      json['originalPath'],
      json['originalUrl'],
    );
    final resultPath = _firstNonEmptyNullable(
      json['resultPath'],
      json['resultUrl'],
    );
    final shared = (json['compartidaConPaciente'] as bool?) ?? false;

    return SimulationModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      originalPath: originalPath,
      resultPath: resultPath,
      compartidaConPaciente: shared,
      createdAt: _parseDate(json['createdAt'], fallback: now),
      updatedAt: _parseNullableDate(json['updatedAt']),
      createdBy: _firstNonEmpty(json['createdBy'], json['creadoPor']),
      treatmentType: _parseTreatmentType(treatmentRaw),
      status: _parseStatus(
        statusRaw: statusRaw,
        shared: shared,
        hasResult: (resultPath ?? '').trim().isNotEmpty,
        legacyModeRaw: legacyModeRaw,
      ),
      notes: json['notes']?.toString(),
      generationProvider: _firstNonEmpty(
        json['generationProvider'],
        'openai',
      ),
      modelUsed: _firstNonEmpty(json['modelUsed'], 'gpt-image-2'),
      attemptCount: _parseInt(json['attemptCount'], fallback: 0),
      errorMessage: json['errorMessage']?.toString(),
      generatedAt: _parseNullableDate(json['generatedAt']),
      promptUsed: json['promptUsed']?.toString(),
      promptVersion: json['promptVersion']?.toString(),
      mlKitUsed: (json['mlKitUsed'] as bool?) ?? false,
      detectedRegion: _asMap(json['detectedRegion']),
      promptMetadata: _asMap(json['promptMetadata']),
      fechaCompartida: _parseNullableDate(json['fechaCompartida']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'originalPath': originalPath,
      'resultPath': resultPath,
      'compartidaConPaciente': compartidaConPaciente,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
      'treatmentType': treatmentType?.name,
      'status': status.name,
      'notes': notes,
      'generationProvider': generationProvider,
      'modelUsed': modelUsed,
      'attemptCount': attemptCount,
      'errorMessage': errorMessage,
      'generatedAt':
          generatedAt == null ? null : Timestamp.fromDate(generatedAt!),
      'promptUsed': promptUsed,
      'promptVersion': promptVersion,
      'mlKitUsed': mlKitUsed,
      'detectedRegion': detectedRegion,
      'promptMetadata': promptMetadata,
      'fechaCompartida': fechaCompartida == null
          ? null
          : Timestamp.fromDate(fechaCompartida!),
    };
  }

  SimulationModel copyWith({
    String? id,
    String? patientId,
    String? originalPath,
    String? resultPath,
    bool clearResultPath = false,
    bool? compartidaConPaciente,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? createdBy,
    TreatmentType? treatmentType,
    bool clearTreatmentType = false,
    SimulationStatus? status,
    String? notes,
    bool clearNotes = false,
    String? generationProvider,
    String? modelUsed,
    int? attemptCount,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? generatedAt,
    bool clearGeneratedAt = false,
    String? promptUsed,
    bool clearPromptUsed = false,
    String? promptVersion,
    bool clearPromptVersion = false,
    bool? mlKitUsed,
    Map<String, dynamic>? detectedRegion,
    bool clearDetectedRegion = false,
    Map<String, dynamic>? promptMetadata,
    bool clearPromptMetadata = false,
    DateTime? fechaCompartida,
    bool clearFechaCompartida = false,
  }) {
    return SimulationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      originalPath: originalPath ?? this.originalPath,
      resultPath: clearResultPath ? null : (resultPath ?? this.resultPath),
      compartidaConPaciente: compartidaConPaciente ?? this.compartidaConPaciente,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      createdBy: createdBy ?? this.createdBy,
      treatmentType: clearTreatmentType ? null : (treatmentType ?? this.treatmentType),
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      generationProvider: generationProvider ?? this.generationProvider,
      modelUsed: modelUsed ?? this.modelUsed,
      attemptCount: attemptCount ?? this.attemptCount,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      generatedAt: clearGeneratedAt ? null : (generatedAt ?? this.generatedAt),
      promptUsed: clearPromptUsed ? null : (promptUsed ?? this.promptUsed),
      promptVersion: clearPromptVersion ? null : (promptVersion ?? this.promptVersion),
      mlKitUsed: mlKitUsed ?? this.mlKitUsed,
      detectedRegion: clearDetectedRegion ? null : (detectedRegion ?? this.detectedRegion),
      promptMetadata: clearPromptMetadata ? null : (promptMetadata ?? this.promptMetadata),
      fechaCompartida: clearFechaCompartida ? null : (fechaCompartida ?? this.fechaCompartida),
    );
  }

  static SimulationStatus _parseStatus({
    required String statusRaw,
    required bool shared,
    required bool hasResult,
    required String legacyModeRaw,
  }) {
    for (final status in SimulationStatus.values) {
      if (status.name == statusRaw) return status;
    }
    if (shared && hasResult) return SimulationStatus.shared;
    if (hasResult) return SimulationStatus.ready;
    if (legacyModeRaw == 'mock' || legacyModeRaw == 'manualDoctora') {
      return hasResult ? SimulationStatus.ready : SimulationStatus.draft;
    }
    return SimulationStatus.draft;
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

  static int _parseInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _firstNonEmpty(dynamic a, dynamic b) {
    final first = (a ?? '').toString().trim();
    if (first.isNotEmpty) return first;
    return (b ?? '').toString();
  }

  static String? _firstNonEmptyNullable(dynamic a, dynamic b) {
    final first = (a ?? '').toString().trim();
    if (first.isNotEmpty) return first;
    final second = (b ?? '').toString().trim();
    if (second.isNotEmpty) return second;
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
