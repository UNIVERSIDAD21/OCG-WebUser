import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kClinicalFileCategories = <String>[
  'radiografia',
  'foto_clinica',
  'foto_intraoral',
  'pdf_clinico',
  'consentimiento',
  'formula',
  'soporte_pago',
  'otro',
];

class ClinicalFileModel {
  const ClinicalFileModel({
    required this.id,
    required this.patientId,
    this.treatmentId,
    this.treatmentNameSnapshot,
    this.stageId,
    this.stageNameSnapshot,
    required this.originalName,
    required this.displayName,
    required this.storagePath,
    this.downloadUrl,
    required this.mimeType,
    required this.extension,
    required this.sizeBytes,
    required this.category,
    this.notes,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.updatedAt,
    required this.active,
    this.visibleToPatient = false,
    this.deletedAt,
    this.deletedBy,
  });

  final String id;
  final String patientId;
  final String? treatmentId;
  final String? treatmentNameSnapshot;
  final String? stageId;
  final String? stageNameSnapshot;
  final String originalName;
  final String displayName;
  final String storagePath;
  final String? downloadUrl;
  final String mimeType;
  final String extension;
  final int sizeBytes;
  final String category;
  final String? notes;
  final String uploadedBy;
  final DateTime uploadedAt;
  final DateTime updatedAt;
  final bool active;
  final bool visibleToPatient;
  final DateTime? deletedAt;
  final String? deletedBy;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  factory ClinicalFileModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final now = DateTime.now();
    return ClinicalFileModel(
      id: id ?? (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      treatmentId: json['treatmentId']?.toString(),
      treatmentNameSnapshot: json['treatmentNameSnapshot']?.toString(),
      stageId: json['stageId']?.toString(),
      stageNameSnapshot: json['stageNameSnapshot']?.toString(),
      originalName: (json['originalName'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      storagePath: (json['storagePath'] ?? '').toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      extension: (json['extension'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? 'otro').toString(),
      notes: json['notes']?.toString(),
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      uploadedAt: _parseDate(json['uploadedAt'], now),
      updatedAt: _parseDate(json['updatedAt'], now),
      active: (json['active'] as bool?) ?? true,
      visibleToPatient: (json['visibleToPatient'] as bool?) ?? false,
      deletedAt: _parseNullableDate(json['deletedAt']),
      deletedBy: json['deletedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'patientId': patientId,
        'treatmentId': treatmentId,
        'treatmentNameSnapshot': treatmentNameSnapshot,
        'stageId': stageId,
        'stageNameSnapshot': stageNameSnapshot,
        'originalName': originalName,
        'displayName': displayName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'mimeType': mimeType,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'category': category,
        'notes': notes,
        'uploadedBy': uploadedBy,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'active': active,
        'visibleToPatient': visibleToPatient,
        'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
        'deletedBy': deletedBy,
      };

  ClinicalFileModel copyWith({
    String? id,
    String? patientId,
    String? treatmentId,
    String? treatmentNameSnapshot,
    String? stageId,
    String? stageNameSnapshot,
    String? originalName,
    String? displayName,
    String? storagePath,
    String? downloadUrl,
    String? mimeType,
    String? extension,
    int? sizeBytes,
    String? category,
    String? notes,
    String? uploadedBy,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    bool? active,
    bool? visibleToPatient,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearTreatment = false,
    bool clearDeleted = false,
  }) {
    return ClinicalFileModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      treatmentId: clearTreatment ? null : (treatmentId ?? this.treatmentId),
      treatmentNameSnapshot: clearTreatment ? null : (treatmentNameSnapshot ?? this.treatmentNameSnapshot),
      stageId: stageId ?? this.stageId,
      stageNameSnapshot: stageNameSnapshot ?? this.stageNameSnapshot,
      originalName: originalName ?? this.originalName,
      displayName: displayName ?? this.displayName,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      mimeType: mimeType ?? this.mimeType,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      active: active ?? this.active,
      visibleToPatient: visibleToPatient ?? this.visibleToPatient,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      deletedBy: clearDeleted ? null : (deletedBy ?? this.deletedBy),
    );
  }

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
}
