import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentType {
  valoracion,
  control,
  instalacion,
  urgencia,
  alta,
}

enum AppointmentStatus {
  programada,
  confirmada,
  completada,
  cancelada,
  noAsistio,
  reprogramada,
}

class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.tipo,
    required this.estado,
    required this.fechaHora,
    required this.duracionMinutos,
    this.notas,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final AppointmentType tipo;
  final AppointmentStatus estado;
  final DateTime fechaHora;
  final int duracionMinutos;
  final String? notas;
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

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final tipoRaw = (json['tipo'] ?? AppointmentType.control.name).toString();
    final estadoRaw = (json['estado'] ?? AppointmentStatus.programada.name).toString();

    return AppointmentModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      tipo: AppointmentType.values.firstWhere(
        (e) => e.name == tipoRaw,
        orElse: () => AppointmentType.control,
      ),
      estado: AppointmentStatus.values.firstWhere(
        (e) => e.name == estadoRaw,
        orElse: () => AppointmentStatus.programada,
      ),
      fechaHora: _parseDate(json['fechaHora']),
      duracionMinutos: (json['duracionMinutos'] as num?)?.toInt() ?? 30,
      notas: json['notas']?.toString(),
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'tipo': tipo.name,
      'estado': estado.name,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'duracionMinutos': duracionMinutos,
      'notas': notas,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    AppointmentType? tipo,
    AppointmentStatus? estado,
    DateTime? fechaHora,
    int? duracionMinutos,
    String? notas,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      fechaHora: fechaHora ?? this.fechaHora,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      notas: notas ?? this.notas,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
