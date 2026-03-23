import 'package:cloud_firestore/cloud_firestore.dart';

enum TreatmentType {
  convencional,
  estetico,
  autoligado,
  alineadores,
  ortopedia,
  interceptivo,
  retenedores,
}

enum TreatmentStage {
  valoracionInicial,
  estudioPlaneacion,
  instalacion,
  controles,
  retencion,
  alta,
}

const Map<TreatmentStage, String> stageNames = {
  TreatmentStage.valoracionInicial: 'Valoración inicial',
  TreatmentStage.estudioPlaneacion: 'Estudio y planeación',
  TreatmentStage.instalacion: 'Instalación',
  TreatmentStage.controles: 'Controles',
  TreatmentStage.retencion: 'Retención',
  TreatmentStage.alta: 'Alta',
};

const Map<TreatmentStage, String> stageDescriptions = {
  TreatmentStage.valoracionInicial:
      'Realizamos tu valoración completa: fotografías clínicas, radiografías panorámica y de perfil, '
      'y modelos de estudio. Esto nos da el punto de partida de tu tratamiento.',
  TreatmentStage.estudioPlaneacion:
      'Con toda la información recopilada, la doctora elabora tu plan de tratamiento personalizado. '
      'Analizamos tu caso en detalle para definir el camino más adecuado para ti.',
  TreatmentStage.instalacion:
      'Instalamos o cementamos tu aparatología de ortodoncia. '
      'Es el inicio oficial del movimiento dental hacia los objetivos de tu plan.',
  TreatmentStage.controles:
      'Fase activa del tratamiento. Pasarás por tres momentos: '
      'primero ordenamos tus dientes (alineación y nivelación), '
      'luego realizamos los ajustes principales (trabajo), '
      'y finalmente los detalles milimétricos (finalización).',
  TreatmentStage.retencion:
      'El tratamiento activo ha concluido. Instalamos tus retenedores para mantener '
      'los resultados obtenidos y estabilizar la posición de tus dientes.',
  TreatmentStage.alta:
      'Tu tratamiento ha finalizado exitosamente. '
      'Hemos alcanzado los objetivos clínicos y estéticos planificados.',
};

const String controlesSubetapasInfo =
    'Alineación y nivelación (aprox. 6–9 meses): ordenamos la posición de tus dientes.\n'
    'Trabajo (aprox. 6–8 meses): cierre de espacios y acople de mordida.\n'
    'Finalización (aprox. 2–6 meses): detalles, ajustes milimétricos y estabilidad.';

class PatientModel {
  const PatientModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.fechaNacimiento,
    this.fotoUrl,
    this.tipoTratamiento,
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

  final TreatmentType? tipoTratamiento;
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

  static TreatmentType? _parseTreatmentType(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return null;
    return TreatmentType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TreatmentType.convencional,
    );
  }

  static TreatmentStage _parseTreatmentStage(dynamic value) {
    final raw = (value ?? '').toString();

    const legacyMap = {
      'diagnostico': TreatmentStage.valoracionInicial,
      'planificacion': TreatmentStage.estudioPlaneacion,
      'seguimientoActivo': TreatmentStage.controles,
      'ajusteFinal': TreatmentStage.controles,
    };

    if (legacyMap.containsKey(raw)) {
      return legacyMap[raw]!;
    }

    return TreatmentStage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TreatmentStage.valoracionInicial,
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
      'tipoTratamiento': tipoTratamiento?.name,
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
