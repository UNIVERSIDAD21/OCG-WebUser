import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialItemModel {
  const FinancialItemModel({
    required this.id,
    required this.patientId,
    required this.treatmentId,
    required this.name,
    required this.normalizedName,
    required this.kind,
    required this.amount,
    this.currency = 'COP',
    required this.deletable,
    required this.editableName,
    required this.order,
    required this.active,
    required this.createdByAdmin,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final String treatmentId;
  final String name;
  final String normalizedName;
  final String kind;
  final double amount;
  final String currency;
  final bool deletable;
  final bool editableName;
  final int order;
  final bool active;
  final bool createdByAdmin;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRequired => kind == 'initial' || kind == 'controls';

  factory FinancialItemModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final now = DateTime.now();
    return FinancialItemModel(
      id: id ?? (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      treatmentId: (json['treatmentId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      normalizedName: (json['normalizedName'] ?? '').toString(),
      kind: (json['kind'] ?? 'extra').toString(),
      amount: _toDouble(json['amount']),
      currency: (json['currency'] ?? 'COP').toString(),
      deletable: (json['deletable'] as bool?) ?? true,
      editableName: (json['editableName'] as bool?) ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
      active: (json['active'] as bool?) ?? true,
      createdByAdmin: (json['createdByAdmin'] as bool?) ?? true,
      createdBy: json['createdBy']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
      createdAt: _parseDate(json['createdAt'], now),
      updatedAt: _parseDate(json['updatedAt'], now),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'patientId': patientId,
        'treatmentId': treatmentId,
        'name': name.trim(),
        'normalizedName': normalizedName.trim(),
        'kind': kind,
        'amount': amount,
        'currency': currency,
        'deletable': deletable,
        'editableName': editableName,
        'order': order,
        'active': active,
        'createdByAdmin': createdByAdmin,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  FinancialItemModel copyWith({
    String? id,
    String? patientId,
    String? treatmentId,
    String? name,
    String? normalizedName,
    String? kind,
    double? amount,
    String? currency,
    bool? deletable,
    bool? editableName,
    int? order,
    bool? active,
    bool? createdByAdmin,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialItemModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      treatmentId: treatmentId ?? this.treatmentId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      deletable: deletable ?? this.deletable,
      editableName: editableName ?? this.editableName,
      order: order ?? this.order,
      active: active ?? this.active,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  static String humanize(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    return clean
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }
}
