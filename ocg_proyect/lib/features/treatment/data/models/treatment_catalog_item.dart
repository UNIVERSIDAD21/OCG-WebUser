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
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String category;
  final String baseType;
  final bool requiresSubtype;
  final List<String> allowedSubtypes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const defaults = <TreatmentCatalogItem>[
    TreatmentCatalogItem(
      id: 'ortopedia',
      name: 'Ortopedia',
      normalizedName: 'ortopedia',
      category: 'ortodoncia',
      baseType: 'ortopedia',
      requiresSubtype: false,
      allowedSubtypes: <String>[],
      active: true,
    ),
    TreatmentCatalogItem(
      id: 'ortodoncia_convencional',
      name: 'Ortodoncia convencional',
      normalizedName: 'ortodoncia_convencional',
      category: 'ortodoncia',
      baseType: 'convencional',
      requiresSubtype: true,
      allowedSubtypes: <String>['metalico', 'estetico'],
      active: true,
    ),
    TreatmentCatalogItem(
      id: 'ortodoncia_autoligado',
      name: 'Ortodoncia autoligado',
      normalizedName: 'ortodoncia_autoligado',
      category: 'ortodoncia',
      baseType: 'autoligado',
      requiresSubtype: true,
      allowedSubtypes: <String>['metalico', 'estetico'],
      active: true,
    ),
    TreatmentCatalogItem(
      id: 'retenedores',
      name: 'Retenedores',
      normalizedName: 'retenedores',
      category: 'ortodoncia',
      baseType: 'retenedores',
      requiresSubtype: false,
      allowedSubtypes: <String>[],
      active: true,
    ),
    TreatmentCatalogItem(
      id: 'blanqueamiento',
      name: 'Blanqueamiento',
      normalizedName: 'blanqueamiento',
      category: 'estetica',
      baseType: 'blanqueamiento',
      requiresSubtype: false,
      allowedSubtypes: <String>[],
      active: true,
    ),
    TreatmentCatalogItem(
      id: 'diseno_sonrisa',
      name: 'Diseño de sonrisa',
      normalizedName: 'diseno_sonrisa',
      category: 'estetica',
      baseType: 'diseno_sonrisa',
      requiresSubtype: false,
      allowedSubtypes: <String>[],
      active: true,
    ),
  ];

  factory TreatmentCatalogItem.fromJson(Map<String, dynamic> json) {
    return TreatmentCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      category: json['category'] as String? ?? 'ortodoncia',
      baseType: json['baseType'] as String? ?? 'convencional',
      requiresSubtype: json['requiresSubtype'] as bool? ?? false,
      allowedSubtypes: (json['allowedSubtypes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      active: json['active'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'category': category,
    'baseType': baseType,
    'requiresSubtype': requiresSubtype,
    'allowedSubtypes': allowedSubtypes,
    'active': active,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
