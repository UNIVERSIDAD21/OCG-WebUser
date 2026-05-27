import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados posibles de una solicitud de urgencia.
enum UrgencyStatus {
  pendiente,      // Recién creada, sin atender
  enProceso,      // Admin la vio y está gestionando
  atendida,       // Se creó cita o se atendió por otro canal
  reprogramada,   // Admin movió cita existente para darle slot a esta urgencia
  rechazada,      // No era urgencia real o no aplica
}

/// Solicitud de atención urgente enviada por un paciente.
class UrgencyRequestModel {
  const UrgencyRequestModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.descripcion,
    required this.estado,
    required this.createdAt,
    this.updatedAt,
    this.appointmentId,          // Si se creó cita desde esta urgencia
    this.reprogramadaFromId,     // ID de la cita que se reprogramó para dar slot
    this.adminNotes,             // Notas del admin al gestionar
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final String descripcion;
  final UrgencyStatus estado;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? appointmentId;
  final String? reprogramadaFromId;
  final String? adminNotes;

  // ─── Serialización ────────────────────────────────────────────────

  factory UrgencyRequestModel.fromJson(Map<String, dynamic> json) {
    return UrgencyRequestModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      patientPhone: (json['patientPhone'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      estado: UrgencyStatus.values.firstWhere(
        (e) => e.name == (json['estado'] ?? 'pendiente').toString(),
        orElse: () => UrgencyStatus.pendiente,
      ),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
      appointmentId: json['appointmentId']?.toString(),
      reprogramadaFromId: json['reprogramadaFromId']?.toString(),
      adminNotes: json['adminNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'descripcion': descripcion,
      'estado': estado.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (reprogramadaFromId != null) 'reprogramadaFromId': reprogramadaFromId,
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }

  /// Crea una copia con los campos modificados.
  UrgencyRequestModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? patientPhone,
    String? descripcion,
    UrgencyStatus? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? appointmentId,
    String? reprogramadaFromId,
    String? adminNotes,
  }) {
    return UrgencyRequestModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appointmentId: appointmentId ?? this.appointmentId,
      reprogramadaFromId: reprogramadaFromId ?? this.reprogramadaFromId,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  // ─── Parsers ──────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Etiqueta legible del estado con emoji.
  String get estadoLabel => switch (estado) {
        UrgencyStatus.pendiente => '⏳ Pendiente',
        UrgencyStatus.enProceso => '🔄 En proceso',
        UrgencyStatus.atendida => '✅ Atendida',
        UrgencyStatus.reprogramada => '📅 Reprogramada',
        UrgencyStatus.rechazada => '❌ Rechazada',
      };

  /// true si la urgencia aún requiere acción del admin.
  bool get isActive =>
      estado == UrgencyStatus.pendiente || estado == UrgencyStatus.enProceso;

  /// Color hex semántico según estado.
  String get statusColorHex => switch (estado) {
        UrgencyStatus.pendiente => '#EF4444',
        UrgencyStatus.enProceso => '#F59E0B',
        UrgencyStatus.atendida => '#10B981',
        UrgencyStatus.reprogramada => '#6366F1',
        UrgencyStatus.rechazada => '#6B7280',
      };

  @override
  String toString() => 'UrgencyRequest($id, $patientName, $estadoLabel)';
}
