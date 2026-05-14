import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../patients/data/models/patient_model.dart';

const List<String> kBaseTreatmentOptions = <String>[
  'convencional',
  'autoligado',
  'alineadores',
  'ortopedia',
  'interceptivo',
  'retenedores',
  'obturacion',
];

const List<String> kOrthodonticBaseTreatments = <String>[
  'convencional',
  'autoligado',
  'alineadores',
  'ortopedia',
  'interceptivo',
  'retenedores',
];

const List<String> kSubtypeRequiredBaseTreatments = <String>[
  'convencional',
  'autoligado',
];

const List<String> kTreatmentSubtypes = <String>['estetico', 'metalico'];

const List<String> kTreatmentStatusOptions = <String>[
  'activo',
  'pausado',
  'finalizado',
  'cancelado',
];

class PatientTreatment {
  const PatientTreatment({
    required this.id,
    required this.patientId,
    required this.nombre,
    this.catalogTreatmentId,
    this.clinicalTreatmentName,
    this.visibleName,
    required this.categoria,
    required this.tipoBase,
    this.subtipo,
    required this.estado,
    required this.etapaActual,
    required this.fechaInicio,
    this.fechaFin,
    required this.createdAt,
    required this.updatedAt,
    required this.isPrimary,
    this.createdBy,
    this.updatedBy,
    this.suggestedCleaningEveryMonths = 3,
    this.suggestedControlEveryMonths = 6,
    this.nextCleaningDate,
    this.nextControlDate,
    this.autoScheduleCleaning = true,
    this.autoScheduleControl = true,
    this.totalTratamiento,
    this.saldoPendiente,
    this.notas,
  });

  final String id;
  final String patientId;
  final String nombre;
  final String? catalogTreatmentId;
  final String? clinicalTreatmentName;
  final String? visibleName;
  final String categoria;
  final String tipoBase;
  final String? subtipo;
  final String estado;
  final TreatmentStage etapaActual;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrimary;
  final String? createdBy;
  final String? updatedBy;
  final int suggestedCleaningEveryMonths;
  final int suggestedControlEveryMonths;
  final DateTime? nextCleaningDate;
  final DateTime? nextControlDate;
  final bool autoScheduleCleaning;
  final bool autoScheduleControl;
  final double? totalTratamiento;
  final double? saldoPendiente;
  final String? notas;

  bool get isActive => estado == 'activo';
  bool get isFinished => estado == 'finalizado' || estado == 'cancelado';
  bool get requiresSubtype => kSubtypeRequiredBaseTreatments.contains(tipoBase);

  String get currentStageId => etapaActual.name;
  String get currentStageName => stageNames[etapaActual] ?? etapaActual.name;
  String get name => nombre;
  String get category => categoria;
  String get baseType => tipoBase;
  String? get subtype => subtipo;
  String get status => estado;
  DateTime get startDate => fechaInicio;
  DateTime? get endDate => fechaFin;

  String get displayName {
    final base = _titleize(nombre);
    final subtype = normalizedSubtypeLabel;
    if (subtype == null || subtype.isEmpty) return base;
    return '$base · $subtype';
  }

  String? get normalizedSubtypeLabel {
    final clean = subtipo?.trim();
    if (clean == null || clean.isEmpty) return null;
    return _titleize(clean);
  }

  String get statusLabel => _titleize(estado.replaceAll('_', ' '));

  static String labelForBaseTreatment(String value) =>
      _titleize(value.replaceAll('_', ' '));

  static String _titleize(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    return words
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String? _legacySubtypeForTreatmentType({
    required TreatmentType? tipoTratamiento,
    required String tipoBase,
  }) {
    if (tipoTratamiento == TreatmentType.estetico) return 'estetico';
    if (!kSubtypeRequiredBaseTreatments.contains(tipoBase)) return null;
    return 'metalico';
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

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory PatientTreatment.fromJson(Map<String, dynamic> json, {String? id}) {
    final now = DateTime.now();
    final stageRaw = json['currentStageId'] ?? json['etapaActual'];
    return PatientTreatment(
      id: id ?? (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      nombre:
          (json['name'] ??
                  json['nombre'] ??
                  json['visibleName'] ??
                  json['clinicalTreatmentName'] ??
                  json['baseType'] ??
                  json['tipoBase'] ??
                  '')
              .toString(),
      catalogTreatmentId: (json['catalogTreatmentId'] as String?)?.trim(),
      clinicalTreatmentName: (json['clinicalTreatmentName'] as String?)?.trim(),
      visibleName: (json['visibleName'] as String?)?.trim(),
      categoria: (json['category'] ?? json['categoria'] ?? 'ortodoncia')
          .toString(),
      tipoBase: (json['baseType'] ?? json['tipoBase'] ?? '').toString(),
      subtipo: (json['subtype'] ?? json['subtipo'])?.toString(),
      estado: (json['status'] ?? json['estado'] ?? 'activo').toString(),
      etapaActual: PatientModel.fromJson(<String, dynamic>{
        'etapaActual': stageRaw,
      }).etapaActual,
      fechaInicio: _parseDate(json['startDate'] ?? json['fechaInicio'], now),
      fechaFin: _parseNullableDate(json['endDate'] ?? json['fechaFin']),
      createdAt: _parseDate(json['createdAt'], now),
      updatedAt: _parseDate(json['updatedAt'], now),
      isPrimary: (json['isPrimary'] as bool?) ?? false,
      createdBy: json['createdBy']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
      suggestedCleaningEveryMonths:
          (json['suggestedCleaningEveryMonths'] as num?)?.toInt() ?? 3,
      suggestedControlEveryMonths:
          (json['suggestedControlEveryMonths'] as num?)?.toInt() ?? 6,
      nextCleaningDate: _parseNullableDate(json['nextCleaningDate']),
      nextControlDate: _parseNullableDate(json['nextControlDate']),
      autoScheduleCleaning: (json['autoScheduleCleaning'] as bool?) ?? true,
      autoScheduleControl: (json['autoScheduleControl'] as bool?) ?? true,
      totalTratamiento: _parseNullableDouble(json['totalTratamiento']),
      saldoPendiente: _parseNullableDouble(json['saldoPendiente']),
      notas: json['notas']?.toString(),
    );
  }

  factory PatientTreatment.fromLegacyPatient(PatientModel patient) {
    final tipoBase = patient.tipoTratamiento == TreatmentType.estetico
        ? 'convencional'
        : (patient.tipoTratamiento?.name ?? 'convencional');
    final nombre = switch (patient.tipoTratamiento) {
      TreatmentType.convencional => 'Convencional',
      TreatmentType.estetico => 'Convencional',
      TreatmentType.autoligado => 'Autoligado',
      TreatmentType.alineadores => 'Alineadores',
      TreatmentType.ortopedia => 'Ortopedia',
      TreatmentType.interceptivo => 'Interceptivo',
      TreatmentType.retenedores => 'Retenedores',
      null => 'Tratamiento principal',
    };
    final subtipo = _legacySubtypeForTreatmentType(
      tipoTratamiento: patient.tipoTratamiento,
      tipoBase: tipoBase,
    );

    return PatientTreatment(
      id: 'legacy-primary-${patient.id}',
      patientId: patient.id,
      nombre: nombre,
      categoria: 'ortodoncia',
      tipoBase: tipoBase,
      subtipo: subtipo,
      estado: patient.isFinished ? 'finalizado' : 'activo',
      etapaActual: patient.etapaActual,
      fechaInicio: patient.fechaInicio,
      fechaFin: patient.isFinished
          ? (patient.updatedAt ?? patient.fechaEstimadaFin)
          : null,
      createdAt: patient.createdAt ?? patient.fechaInicio,
      updatedAt: patient.updatedAt ?? patient.fechaInicio,
      isPrimary: true,
      totalTratamiento: patient.totalTratamiento,
      saldoPendiente: patient.saldoPendiente,
      notas: patient.notasClinicas,
    );
  }

  PatientTreatment copyWith({
    String? id,
    String? nombre,
    String? catalogTreatmentId,
    String? clinicalTreatmentName,
    String? visibleName,
    String? categoria,
    String? tipoBase,
    String? patientId,
    String? subtipo,
    String? estado,
    TreatmentStage? etapaActual,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrimary,
    String? createdBy,
    String? updatedBy,
    int? suggestedCleaningEveryMonths,
    int? suggestedControlEveryMonths,
    DateTime? nextCleaningDate,
    DateTime? nextControlDate,
    bool? autoScheduleCleaning,
    bool? autoScheduleControl,
    double? totalTratamiento,
    double? saldoPendiente,
    String? notas,
    bool clearSubtype = false,
    bool clearFinancials = false,
    bool clearNotes = false,
  }) {
    return PatientTreatment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      nombre: nombre ?? this.nombre,
      catalogTreatmentId: catalogTreatmentId ?? this.catalogTreatmentId,
      clinicalTreatmentName:
          clinicalTreatmentName ?? this.clinicalTreatmentName,
      visibleName: visibleName ?? this.visibleName,
      categoria: categoria ?? this.categoria,
      tipoBase: tipoBase ?? this.tipoBase,
      subtipo: clearSubtype ? null : (subtipo ?? this.subtipo),
      estado: estado ?? this.estado,
      etapaActual: etapaActual ?? this.etapaActual,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrimary: isPrimary ?? this.isPrimary,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      suggestedCleaningEveryMonths:
          suggestedCleaningEveryMonths ?? this.suggestedCleaningEveryMonths,
      suggestedControlEveryMonths:
          suggestedControlEveryMonths ?? this.suggestedControlEveryMonths,
      nextCleaningDate: nextCleaningDate ?? this.nextCleaningDate,
      nextControlDate: nextControlDate ?? this.nextControlDate,
      autoScheduleCleaning: autoScheduleCleaning ?? this.autoScheduleCleaning,
      autoScheduleControl: autoScheduleControl ?? this.autoScheduleControl,
      totalTratamiento: clearFinancials
          ? null
          : (totalTratamiento ?? this.totalTratamiento),
      saldoPendiente: clearFinancials
          ? null
          : (saldoPendiente ?? this.saldoPendiente),
      notas: clearNotes ? null : (notas ?? this.notas),
    );
  }

  Map<String, dynamic> toJson() {
    final cleanName = nombre.trim();
    final cleanCategory = categoria.trim().isEmpty
        ? 'ortodoncia'
        : categoria.trim();
    final cleanBaseType = tipoBase.trim();
    final cleanSubtype = subtipo?.trim().isEmpty ?? true
        ? null
        : subtipo?.trim();
    final cleanStatus = estado.trim();

    return <String, dynamic>{
      'id': id,
      'patientId': patientId,
      'name': cleanName,
      'catalogTreatmentId': catalogTreatmentId,
      'clinicalTreatmentName': (clinicalTreatmentName ?? cleanName).trim(),
      'visibleName': (visibleName ?? cleanName).trim(),
      'category': cleanCategory,
      'baseType': cleanBaseType,
      'subtype': cleanSubtype,
      'status': cleanStatus,
      'currentStageId': etapaActual.name,
      'currentStageName': currentStageName,
      'isPrimary': isPrimary,
      'startDate': Timestamp.fromDate(fechaInicio),
      'endDate': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      // Compatibilidad temporal con pantallas/código legado del repo.
      'nombre': cleanName,
      'categoria': cleanCategory,
      'tipoBase': cleanBaseType,
      'subtipo': cleanSubtype,
      'estado': cleanStatus,
      'etapaActual': etapaActual.name,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
      'suggestedCleaningEveryMonths': suggestedCleaningEveryMonths,
      'suggestedControlEveryMonths': suggestedControlEveryMonths,
      'nextCleaningDate': nextCleaningDate == null
          ? null
          : Timestamp.fromDate(nextCleaningDate!),
      'nextControlDate': nextControlDate == null
          ? null
          : Timestamp.fromDate(nextControlDate!),
      'autoScheduleCleaning': autoScheduleCleaning,
      'autoScheduleControl': autoScheduleControl,
      'totalTratamiento': totalTratamiento,
      'saldoPendiente': saldoPendiente,
      'notas': notas,
    };
  }
}
