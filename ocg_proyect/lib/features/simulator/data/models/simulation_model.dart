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
    this.treatmentProfileId,
    this.visualGoal,
    this.doctorConfig,
    this.doctorOverride,
    this.photoQuality,
    this.doctorReviewStatus = 'pending',
    this.approvedAttemptId,
  });

  // ── Campos base ──────────────────────────────────────
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

  // ── Campos nuevos Bloque 01 ──────────────────────────
  final String? treatmentProfileId;
  final String? visualGoal;
  final Map<String, dynamic>? doctorConfig;
  /// Instrucciones libres del doctor en lenguaje natural.
  final String? doctorOverride;
  final Map<String, dynamic>? photoQuality;
  final String doctorReviewStatus; // pending | approved | rejected
  final String? approvedAttemptId;

  // ── Convenience ──────────────────────────────────────
  String get originalUrl => originalPath;
  String? get resultUrl => resultPath;
  bool get hasResult =>
      resultPath?.trim().isNotEmpty == true ||
      resultUrl?.trim().isNotEmpty == true;

  // ── fromJson ─────────────────────────────────────────
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
      // ── Campos nuevos con defaults ────────────────────
      treatmentProfileId: _nullableString(json['treatmentProfileId']),
      visualGoal: _nullableString(json['visualGoal']),
      doctorConfig: _asMap(json['doctorConfig']),
      doctorOverride: _nullableString(json['doctorOverride']),
      photoQuality: _asMap(json['photoQuality']),
      doctorReviewStatus:
          _firstNonEmpty(json['doctorReviewStatus'], 'pending'),
      approvedAttemptId: _nullableString(json['approvedAttemptId']),
    );
  }

  // ── toJson ───────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'patientId': patientId,
      'originalPath': originalPath,
      'compartidaConPaciente': compartidaConPaciente,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'treatmentType': treatmentType?.name,
      'status': status.name,
      'generationProvider': generationProvider,
      'modelUsed': modelUsed,
      'attemptCount': attemptCount,
      'mlKitUsed': mlKitUsed,
      'doctorReviewStatus': doctorReviewStatus,
    };

    if (resultPath != null) {
      map['resultPath'] = resultPath;
    }
    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }
    if (notes != null) {
      map['notes'] = notes;
    }
    if (errorMessage != null) {
      map['errorMessage'] = errorMessage;
    }
    if (generatedAt != null) {
      map['generatedAt'] = Timestamp.fromDate(generatedAt!);
    }
    if (promptUsed != null) {
      map['promptUsed'] = promptUsed;
    }
    if (promptVersion != null) {
      map['promptVersion'] = promptVersion;
    }
    if (detectedRegion != null) {
      map['detectedRegion'] = detectedRegion;
    }
    if (promptMetadata != null) {
      map['promptMetadata'] = promptMetadata;
    }
    if (fechaCompartida != null) {
      map['fechaCompartida'] = Timestamp.fromDate(fechaCompartida!);
    }
    // ── Campos nuevos (solo si no son vacíos/nulos) ─────
    final tpId = (treatmentProfileId ?? '').trim();
    if (tpId.isNotEmpty) {
      map['treatmentProfileId'] = tpId;
    }
    final vg = (visualGoal ?? '').trim();
    if (vg.isNotEmpty) {
      map['visualGoal'] = vg;
    }
    if (doctorConfig != null && doctorConfig!.isNotEmpty) {
      map['doctorConfig'] = doctorConfig;
    }
    final doStr = (doctorOverride ?? '').trim();
    if (doStr.isNotEmpty) {
      map['doctorOverride'] = doctorOverride;
    }
    if (photoQuality != null && photoQuality!.isNotEmpty) {
      map['photoQuality'] = photoQuality;
    }
    final aaId = (approvedAttemptId ?? '').trim();
    if (aaId.isNotEmpty) {
      map['approvedAttemptId'] = aaId;
    }

    return map;
  }

  // ── copyWith ─────────────────────────────────────────
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
    // ── Campos nuevos ──────────────────────────────────
    String? treatmentProfileId,
    bool clearTreatmentProfileId = false,
    String? visualGoal,
    bool clearVisualGoal = false,
    Map<String, dynamic>? doctorConfig,
    bool clearDoctorConfig = false,
    String? doctorOverride,
    bool clearDoctorOverride = false,
    Map<String, dynamic>? photoQuality,
    bool clearPhotoQuality = false,
    String? doctorReviewStatus,
    String? approvedAttemptId,
    bool clearApprovedAttemptId = false,
  }) {
    return SimulationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      originalPath: originalPath ?? this.originalPath,
      resultPath: clearResultPath ? null : (resultPath ?? this.resultPath),
      compartidaConPaciente:
          compartidaConPaciente ?? this.compartidaConPaciente,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      createdBy: createdBy ?? this.createdBy,
      treatmentType:
          clearTreatmentType ? null : (treatmentType ?? this.treatmentType),
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      generationProvider: generationProvider ?? this.generationProvider,
      modelUsed: modelUsed ?? this.modelUsed,
      attemptCount: attemptCount ?? this.attemptCount,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      generatedAt:
          clearGeneratedAt ? null : (generatedAt ?? this.generatedAt),
      promptUsed:
          clearPromptUsed ? null : (promptUsed ?? this.promptUsed),
      promptVersion:
          clearPromptVersion ? null : (promptVersion ?? this.promptVersion),
      mlKitUsed: mlKitUsed ?? this.mlKitUsed,
      detectedRegion:
          clearDetectedRegion ? null : (detectedRegion ?? this.detectedRegion),
      promptMetadata:
          clearPromptMetadata ? null : (promptMetadata ?? this.promptMetadata),
      fechaCompartida: clearFechaCompartida
          ? null
          : (fechaCompartida ?? this.fechaCompartida),
      // ── Campos nuevos ──────────────────────────────────
      treatmentProfileId: clearTreatmentProfileId
          ? null
          : (treatmentProfileId ?? this.treatmentProfileId),
      visualGoal:
          clearVisualGoal ? null : (visualGoal ?? this.visualGoal),
      doctorConfig:
          clearDoctorConfig ? null : (doctorConfig ?? this.doctorConfig),
      doctorOverride:
          clearDoctorOverride ? null : (doctorOverride ?? this.doctorOverride),
      photoQuality:
          clearPhotoQuality ? null : (photoQuality ?? this.photoQuality),
      doctorReviewStatus: doctorReviewStatus ?? this.doctorReviewStatus,
      approvedAttemptId: clearApprovedAttemptId
          ? null
          : (approvedAttemptId ?? this.approvedAttemptId),
    );
  }

  // ── Parsers internos ─────────────────────────────────

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

  static String? _nullableString(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
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
