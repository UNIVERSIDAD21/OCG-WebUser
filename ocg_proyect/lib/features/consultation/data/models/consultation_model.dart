import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../patients/data/models/patient_model.dart';

// ─── Estados de una consulta ─────────────────────────────────────────────────

enum ConsultationStatus {
  draft,
  pendingSignature,
  completed,
  voided,
}

// ─── Fase en el momento de la consulta (para auditoría) ──────────────────────

class PhaseSnapshot {
  const PhaseSnapshot({
    required this.previousStage,
    required this.currentStage,
    this.phaseAdvanced = false,
  });

  final TreatmentStage previousStage;
  final TreatmentStage currentStage;
  final bool phaseAdvanced;

  factory PhaseSnapshot.fromJson(Map<String, dynamic> json) {
    return PhaseSnapshot(
      previousStage: _parseStage(json['previousStage']),
      currentStage: _parseStage(json['currentStage']),
      phaseAdvanced: (json['phaseAdvanced'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'previousStage': previousStage.name,
      'currentStage': currentStage.name,
      'phaseAdvanced': phaseAdvanced,
    };
  }

  static TreatmentStage _parseStage(dynamic value) {
    final raw = (value ?? '').toString();
    return TreatmentStage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TreatmentStage.valoracionInicial,
    );
  }
}

// ─── Entrada de auditoría ────────────────────────────────────────────────────

class AuditEntry {
  const AuditEntry({
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.timestamp,
    this.details,
  });

  final String action; // 'created', 'signature_added', 'completed', 'voided'
  final String actorId;
  final String actorName;
  final DateTime timestamp;
  final String? details;

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      action: (json['action'] ?? '').toString(),
      actorId: (json['actorId'] ?? '').toString(),
      actorName: (json['actorName'] ?? '').toString(),
      timestamp: _parseDate(json['timestamp']),
      details: json['details']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

// ─── Modelo principal de consulta clínica ────────────────────────────────────

class ConsultationModel {
  const ConsultationModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    this.clinicalNotes = '',
    this.photos = const [],
    this.phaseSnapshot,
    this.signatureUrl,
    this.signatureCapturedAt,
    this.status = ConsultationStatus.draft,
    this.auditTrail = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String? appointmentId;
  final String doctorId;
  final String doctorName;
  final DateTime date;
  final String clinicalNotes;
  final List<String> photos;
  final PhaseSnapshot? phaseSnapshot;
  final String? signatureUrl;
  final DateTime? signatureCapturedAt;
  final ConsultationStatus status;
  final List<AuditEntry> auditTrail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasSignature => signatureUrl != null && signatureUrl!.isNotEmpty;
  bool get isCompleted => status == ConsultationStatus.completed;
  bool get requiresSignature =>
      status == ConsultationStatus.draft ||
      status == ConsultationStatus.pendingSignature;

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory ConsultationModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final statusRaw = (json['status'] ?? ConsultationStatus.draft.name).toString();
    final photosRaw = json['photos'];
    final auditRaw = json['auditTrail'];

    List<String> parsePhotos(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    List<AuditEntry> parseAudit(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .where((e) => e is Map<String, dynamic>)
            .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return ConsultationModel(
      id: id ?? (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      appointmentId: json['appointmentId']?.toString(),
      doctorId: (json['doctorId'] ?? '').toString(),
      doctorName: (json['doctorName'] ?? '').toString(),
      date: _parseDate(json['date']),
      clinicalNotes: (json['clinicalNotes'] ?? '').toString(),
      photos: parsePhotos(photosRaw),
      phaseSnapshot: json['phaseSnapshot'] != null
          ? PhaseSnapshot.fromJson(
              (json['phaseSnapshot'] as Map<String, dynamic>))
          : null,
      signatureUrl: json['signatureUrl']?.toString(),
      signatureCapturedAt: _parseNullableDate(json['signatureCapturedAt']),
      status: ConsultationStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => ConsultationStatus.draft,
      ),
      auditTrail: parseAudit(auditRaw),
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'date': Timestamp.fromDate(date),
      'clinicalNotes': clinicalNotes,
      'photos': photos,
      'phaseSnapshot': phaseSnapshot?.toJson(),
      'signatureUrl': signatureUrl,
      'signatureCapturedAt':
          signatureCapturedAt == null ? null : Timestamp.fromDate(signatureCapturedAt!),
      'status': status.name,
      'auditTrail': auditTrail.map((e) => e.toJson()).toList(),
      'createdAt':
          createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ConsultationModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? appointmentId,
    String? doctorId,
    String? doctorName,
    DateTime? date,
    String? clinicalNotes,
    List<String>? photos,
    PhaseSnapshot? phaseSnapshot,
    String? signatureUrl,
    DateTime? signatureCapturedAt,
    ConsultationStatus? status,
    List<AuditEntry>? auditTrail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConsultationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      photos: photos ?? this.photos,
      phaseSnapshot: phaseSnapshot ?? this.phaseSnapshot,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      signatureCapturedAt: signatureCapturedAt ?? this.signatureCapturedAt,
      status: status ?? this.status,
      auditTrail: auditTrail ?? this.auditTrail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
