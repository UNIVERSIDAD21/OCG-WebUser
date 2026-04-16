import 'package:cloud_firestore/cloud_firestore.dart';

class TreatmentCatalogItem {
  const TreatmentCatalogItem({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.category,
    required this.baseType,
    required this.requiresSubtype,
    required this.allowedSubtypes,
    required this.isSystemDefault,
    required this.active,
    required this.createdAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String category;
  final String baseType;
  final bool requiresSubtype;
  final List<String> allowedSubtypes;
  final bool isSystemDefault;
  final bool active;
  final DateTime createdAt;
  final String? createdBy;

  factory TreatmentCatalogItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return TreatmentCatalogItem(
      id: id ?? (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      normalizedName: (json['normalizedName'] ?? '').toString(),
      category: (json['category'] ?? 'ortodoncia').toString(),
      baseType: (json['baseType'] ?? json['normalizedName'] ?? '').toString(),
      requiresSubtype: (json['requiresSubtype'] as bool?) ?? false,
      allowedSubtypes: ((json['allowedSubtypes'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      isSystemDefault: (json['isSystemDefault'] as bool?) ?? false,
      active: (json['active'] as bool?) ?? true,
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'normalizedName': normalizedName,
      'category': category,
      'baseType': baseType,
      'requiresSubtype': requiresSubtype,
      'allowedSubtypes': allowedSubtypes,
      'isSystemDefault': isSystemDefault,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
