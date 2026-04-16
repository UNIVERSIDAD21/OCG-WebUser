import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentType { valoracion, control, instalacion, urgencia, alta }

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
    required this.patientPhone,
    this.treatmentId,
    required this.tipo,
    required this.estado,
    required this.fechaHora,
    required this.duracionMinutos,
    required this.creadoPor,
    this.notas,
    this.recordatorio24hEnviado = false,
    this.recordatorio2hEnviado = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;

  /// telefono del paciente — para contacto rápido del admin
  final String patientPhone;
  final String? treatmentId;

  final AppointmentType tipo;
  final AppointmentStatus estado;
  final DateTime fechaHora;
  final int duracionMinutos;

  /// 'admin' o el patientId de quien creó la cita
  final String creadoPor;

  final String? notas;

  /// Flags para Cloud Functions de recordatorios FCM
  final bool recordatorio24hEnviado;
  final bool recordatorio2hEnviado;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ─── Parsers internos ─────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    }
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ─── Serialización ────────────────────────────────────────────────────────

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final tipoRaw = (json['tipo'] ?? AppointmentType.control.name).toString();
    final estadoRaw = (json['estado'] ?? AppointmentStatus.programada.name)
        .toString();

    return AppointmentModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      // patientPhone — tolera documentos viejos sin el campo
      patientPhone: (json['patientPhone'] ?? '').toString(),
      treatmentId: json['treatmentId']?.toString(),
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
      // creadoPor — tolera documentos viejos sin el campo
      creadoPor: (json['creadoPor'] ?? 'admin').toString(),
      notas: json['notas']?.toString(),
      // recordatorios — tolera documentos viejos sin el campo (default false)
      recordatorio24hEnviado:
          (json['recordatorio24hEnviado'] as bool?) ?? false,
      recordatorio2hEnviado: (json['recordatorio2hEnviado'] as bool?) ?? false,
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'treatmentId': treatmentId,
      'tipo': tipo.name,
      'estado': estado.name,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'duracionMinutos': duracionMinutos,
      'creadoPor': creadoPor,
      'notas': notas ?? '',
      'recordatorio24hEnviado': recordatorio24hEnviado,
      'recordatorio2hEnviado': recordatorio2hEnviado,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? patientPhone,
    String? treatmentId,
    AppointmentType? tipo,
    AppointmentStatus? estado,
    DateTime? fechaHora,
    int? duracionMinutos,
    String? creadoPor,
    String? notas,
    bool? recordatorio24hEnviado,
    bool? recordatorio2hEnviado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      treatmentId: treatmentId ?? this.treatmentId,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      fechaHora: fechaHora ?? this.fechaHora,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      creadoPor: creadoPor ?? this.creadoPor,
      notas: notas ?? this.notas,
      recordatorio24hEnviado:
          recordatorio24hEnviado ?? this.recordatorio24hEnviado,
      recordatorio2hEnviado:
          recordatorio2hEnviado ?? this.recordatorio2hEnviado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
