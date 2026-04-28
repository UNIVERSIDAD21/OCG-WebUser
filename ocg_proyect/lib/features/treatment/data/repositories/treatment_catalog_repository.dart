import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/treatment_catalog_item.dart';

class TreatmentCatalogRepository {
  TreatmentCatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _catalogRef =>
      _db.collection(FirestorePaths.treatmentCatalog);

  Stream<List<TreatmentCatalogItem>> watchCatalog() {
    return _catalogRef.orderBy('name').snapshots().map((snap) {
      final remote = snap.docs
          .map((doc) => TreatmentCatalogItem.fromJson(doc.data()))
          .where((item) => item.active)
          .toList();
      if (remote.isEmpty) return TreatmentCatalogItem.defaults;
      final merged = [...remote];
      for (final item in TreatmentCatalogItem.defaults) {
        final exists = merged.any(
          (e) => e.normalizedName == item.normalizedName,
        );
        if (!exists) merged.add(item);
      }
      merged.sort((a, b) => a.name.compareTo(b.name));
      return merged;
    });
  }

  Future<TreatmentCatalogItem> createCatalogItem({
    required String name,
    required String category,
    required String baseType,
    required bool requiresSubtype,
    required List<String> allowedSubtypes,
    String? createdBy,
  }) async {
    final displayName = _displayName(name);
    if (displayName.isEmpty) {
      throw Exception('TREATMENT_CATALOG_NAME_REQUIRED');
    }

    final normalized = _normalize(displayName);
    final normalizedBaseType = _normalize(baseType);
    final normalizedCategory = category.trim().toLowerCase();
    final existing = await _catalogRef
        .where('normalizedName', isEqualTo: normalized)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return TreatmentCatalogItem.fromJson(existing.docs.first.data());
    }

    final now = DateTime.now();
    final ref = _catalogRef.doc(normalized);
    final item = TreatmentCatalogItem(
      id: ref.id,
      name: displayName,
      normalizedName: normalized,
      category: normalizedCategory,
      baseType: normalizedBaseType,
      requiresSubtype: requiresSubtype,
      allowedSubtypes: requiresSubtype ? allowedSubtypes : const <String>[],
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set({
      ...item.toJson(),
      'createdBy': createdBy ?? 'system',
      'updatedBy': createdBy ?? 'system',
    }, SetOptions(merge: true));
    return item;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  String _displayName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
