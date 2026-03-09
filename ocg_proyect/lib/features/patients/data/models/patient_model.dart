import 'package:cloud_firestore/cloud_firestore.dart';

enum TreatmentType {
  convencional,
  estetico,
  autoligado,
  alineadores,
  ortopedia,
  retenedores,
}

enum TreatmentStage {
  diagnostico,
  planificacion,
  instalacion,
  seguimientoActivo,
  ajusteFinal,
  retencion,
  alta,
}

class PatientModel {
  const PatientModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.fechaNacimiento,
    this.fotoUrl,
    required this.tipoTratamiento,
    required this.etapaActual,
    required this.fechaInicio,
    this.fechaEstimadaFin,
    required this.notasClinicas,
    required this.totalTratamiento,
    required this.saldoPendiente,
    this.fechaProximoPago,
    this.proximaCita,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final DateTime fechaNacimiento;
  final String? fotoUrl;

  final TreatmentType tipoTratamiento;
  final TreatmentStage etapaActual;
  final DateTime fechaInicio;
  final DateTime? fechaEstimadaFin;
  final String notasClinicas;

  final double totalTratamiento;
  final double saldoPendiente;
  final DateTime? fechaProximoPago;
  final DateTime? proximaCita;

  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static TreatmentType _parseTreatmentType(dynamic value) {
    final raw = (value ?? '').toString();
    return TreatmentType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TreatmentType.convencional,
    );
  }

  static TreatmentStage _parseTreatmentStage(dynamic value) {
    final raw = (value ?? '').toString();
    return TreatmentStage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TreatmentStage.diagnostico,
    );
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: (json['id'] ?? json['uid'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['displayName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      fechaNacimiento: _parseDate(json['fechaNacimiento']),
      fotoUrl: json['fotoUrl']?.toString(),
      tipoTratamiento: _parseTreatmentType(json['tipoTratamiento']),
      etapaActual: _parseTreatmentStage(json['etapaActual']),
      fechaInicio: _parseDate(json['fechaInicio']),
      fechaEstimadaFin: _parseNullableDate(json['fechaEstimadaFin']),
      notasClinicas: (json['notasClinicas'] ?? '').toString(),
      totalTratamiento: _toDouble(json['totalTratamiento']),
      saldoPendiente: _toDouble(json['saldoPendiente']),
      fechaProximoPago: _parseNullableDate(json['fechaProximoPago']),
      proximaCita: _parseNullableDate(json['proximaCita']),
      fcmToken: json['fcmToken']?.toString(),
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
      'fotoUrl': fotoUrl,
      'tipoTratamiento': tipoTratamiento.name,
      'etapaActual': etapaActual.name,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaEstimadaFin': fechaEstimadaFin == null ? null : Timestamp.fromDate(fechaEstimadaFin!),
      'notasClinicas': notasClinicas,
      'totalTratamiento': totalTratamiento,
      'saldoPendiente': saldoPendiente,
      'fechaProximoPago': fechaProximoPago == null ? null : Timestamp.fromDate(fechaProximoPago!),
      'proximaCita': proximaCita == null ? null : Timestamp.fromDate(proximaCita!),
      'fcmToken': fcmToken,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
