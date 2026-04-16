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

const List<String> kTreatmentSubtypes = <String>[
  'estetico',
  'metalico',
];

const List<String> kTreatmentStatusOptions = <String>[
  'activo',
  'pausado',
  'finalizado',
  'cancelado',
];

class PatientTreatment {
  const PatientTreatment({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.tipoBase,
    this.subtipo,
    required this.estado,
    required this.etapaActual,
    required this.fechaInicio,
    required this.createdAt,
    required this.updatedAt,
    required this.isPrimary,
    this.suggestedCleaningEveryMonths = 3,
    this.suggestedControlEveryMonths = 6,
    this.totalTratamiento,
    this.saldoPendiente,
    this.notas,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String tipoBase;
  final String? subtipo;
  final String estado;
  final TreatmentStage etapaActual;
  final DateTime fechaInicio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrimary;
  final int suggestedCleaningEveryMonths;
  final int suggestedControlEveryMonths;
  final double? totalTratamiento;
  final double? saldoPendiente;
  final String? notas;

  bool get isActive => estado == 'activo';
  bool get isFinished => estado == 'finalizado' || estado == 'cancelado';
  bool get requiresSubtype => kSubtypeRequiredBaseTreatments.contains(tipoBase);

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

  static String labelForBaseTreatment(String value) => _titleize(value.replaceAll('_', ' '));

  static String _titleize(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory PatientTreatment.fromJson(Map<String, dynamic> json, {String? id}) {
    final now = DateTime.now();
    return PatientTreatment(
      id: id ?? (json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['tipoBase'] ?? '').toString(),
      categoria: (json['categoria'] ?? 'ortodoncia').toString(),
      tipoBase: (json['tipoBase'] ?? '').toString(),
      subtipo: json['subtipo']?.toString(),
      estado: (json['estado'] ?? 'activo').toString(),
      etapaActual: PatientModel.fromJson(<String, dynamic>{'etapaActual': json['etapaActual']}).etapaActual,
      fechaInicio: _parseDate(json['fechaInicio'], now),
      createdAt: _parseDate(json['createdAt'], now),
      updatedAt: _parseDate(json['updatedAt'], now),
      isPrimary: (json['isPrimary'] as bool?) ?? false,
      suggestedCleaningEveryMonths: (json['suggestedCleaningEveryMonths'] as num?)?.toInt() ?? 3,
      suggestedControlEveryMonths: (json['suggestedControlEveryMonths'] as num?)?.toInt() ?? 6,
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
    final subtipo = patient.tipoTratamiento == TreatmentType.estetico ? 'estetico' : null;

    return PatientTreatment(
      id: 'legacy-primary-${patient.id}',
      nombre: nombre,
      categoria: 'ortodoncia',
      tipoBase: tipoBase,
      subtipo: subtipo,
      estado: patient.isFinished ? 'finalizado' : 'activo',
      etapaActual: patient.etapaActual,
      fechaInicio: patient.fechaInicio,
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
    String? categoria,
    String? tipoBase,
    String? subtipo,
    String? estado,
    TreatmentStage? etapaActual,
    DateTime? fechaInicio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrimary,
    int? suggestedCleaningEveryMonths,
    int? suggestedControlEveryMonths,
    double? totalTratamiento,
    double? saldoPendiente,
    String? notas,
    bool clearSubtype = false,
    bool clearFinancials = false,
    bool clearNotes = false,
  }) {
    return PatientTreatment(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      tipoBase: tipoBase ?? this.tipoBase,
      subtipo: clearSubtype ? null : (subtipo ?? this.subtipo),
      estado: estado ?? this.estado,
      etapaActual: etapaActual ?? this.etapaActual,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrimary: isPrimary ?? this.isPrimary,
      suggestedCleaningEveryMonths:
          suggestedCleaningEveryMonths ?? this.suggestedCleaningEveryMonths,
      suggestedControlEveryMonths:
          suggestedControlEveryMonths ?? this.suggestedControlEveryMonths,
      totalTratamiento: clearFinancials ? null : (totalTratamiento ?? this.totalTratamiento),
      saldoPendiente: clearFinancials ? null : (saldoPendiente ?? this.saldoPendiente),
      notas: clearNotes ? null : (notas ?? this.notas),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nombre': nombre.trim(),
      'categoria': categoria.trim().isEmpty ? 'ortodoncia' : categoria.trim(),
      'tipoBase': tipoBase.trim(),
      'subtipo': subtipo?.trim().isEmpty ?? true ? null : subtipo?.trim(),
      'estado': estado.trim(),
      'etapaActual': etapaActual.name,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPrimary': isPrimary,
      'suggestedCleaningEveryMonths': suggestedCleaningEveryMonths,
      'suggestedControlEveryMonths': suggestedControlEveryMonths,
      'totalTratamiento': totalTratamiento,
      'saldoPendiente': saldoPendiente,
      'notas': notas,
    };
  }
}
