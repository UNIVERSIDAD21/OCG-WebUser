import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { alDia, pendiente, vencido, pagadoTotal }

enum PaymentMethod { efectivo, transferencia, payu }

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.patientId,
    required this.totalTratamiento,
    required this.montoPagado,
    required this.saldoPendiente,
    required this.fechaProximoPago,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final double totalTratamiento;
  final double montoPagado;
  final double saldoPendiente;
  final DateTime? fechaProximoPago;
  final PaymentStatus estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return PaymentModel(
      id: (json['id'] ?? json['patientId'] ?? '').toString(),
      patientId: (json['patientId'] ?? json['id'] ?? '').toString(),
      totalTratamiento: _toDouble(json['totalTratamiento']),
      montoPagado: _toDouble(json['montoPagado']),
      saldoPendiente: _toDouble(json['saldoPendiente']),
      fechaProximoPago: _parseNullableDate(json['fechaProximoPago']),
      estado: PaymentStatus.values.firstWhere(
        (e) => e.name == (json['estado'] ?? '').toString(),
        orElse: () => calcularEstado(
          saldoPendiente: _toDouble(json['saldoPendiente']),
          fechaProximoPago: _parseNullableDate(json['fechaProximoPago']),
        ),
      ),
      createdAt: _parseDate(json['createdAt'], fallback: now),
      updatedAt: _parseDate(json['updatedAt'], fallback: now),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'totalTratamiento': totalTratamiento,
    'montoPagado': montoPagado,
    'saldoPendiente': saldoPendiente,
    'fechaProximoPago': fechaProximoPago == null ? null : Timestamp.fromDate(fechaProximoPago!),
    'estado': estado.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  PaymentModel copyWith({
    String? id,
    String? patientId,
    double? totalTratamiento,
    double? montoPagado,
    double? saldoPendiente,
    DateTime? fechaProximoPago,
    bool clearFechaProximoPago = false,
    PaymentStatus? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      totalTratamiento: totalTratamiento ?? this.totalTratamiento,
      montoPagado: montoPagado ?? this.montoPagado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      fechaProximoPago: clearFechaProximoPago ? null : (fechaProximoPago ?? this.fechaProximoPago),
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static PaymentStatus calcularEstado({
    required double saldoPendiente,
    required DateTime? fechaProximoPago,
    DateTime? now,
  }) {
    if (saldoPendiente <= 0) return PaymentStatus.pagadoTotal;
    if (fechaProximoPago == null) return PaymentStatus.pendiente;

    final refNow = now ?? DateTime.now();
    if (fechaProximoPago.isBefore(refNow)) return PaymentStatus.vencido;
    if (!fechaProximoPago.isAfter(refNow.add(const Duration(days: 7)))) {
      return PaymentStatus.pendiente;
    }
    return PaymentStatus.alDia;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDate(dynamic value, {required DateTime fallback}) {
    if (value == null) return fallback;
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

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.metodo,
    required this.registradoPor,
    this.referencia,
    this.notas,
    this.reciboUrl,
    this.payuOrderId,
    this.payuTransactionId,
    this.treatmentId,
  });

  final String id;
  final double monto;
  final DateTime fecha;
  final PaymentMethod metodo;
  final String? referencia;
  final String registradoPor;
  final String? notas;
  final String? reciboUrl;
  final String? payuOrderId;
  final String? payuTransactionId;
  final String? treatmentId;

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: (json['id'] ?? '').toString(),
      monto: PaymentModel._toDouble(json['monto']),
      fecha: PaymentModel._parseDate(json['fecha'], fallback: DateTime.now()),
      metodo: PaymentMethod.values.firstWhere(
        (e) => e.name == (json['metodo'] ?? '').toString(),
        orElse: () => PaymentMethod.efectivo,
      ),
      referencia: json['referencia']?.toString(),
      registradoPor: (json['registradoPor'] ?? '').toString(),
      notas: json['notas']?.toString(),
      reciboUrl: json['reciboUrl']?.toString(),
      payuOrderId: json['payuOrderId']?.toString(),
      payuTransactionId: json['payuTransactionId']?.toString(),
      treatmentId: json['treatmentId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'monto': monto,
    'fecha': Timestamp.fromDate(fecha),
    'metodo': metodo.name,
    'referencia': referencia,
    'registradoPor': registradoPor,
    'notas': notas,
    'reciboUrl': reciboUrl,
    'payuOrderId': payuOrderId,
    'payuTransactionId': payuTransactionId,
    'treatmentId': treatmentId,
  };
}
