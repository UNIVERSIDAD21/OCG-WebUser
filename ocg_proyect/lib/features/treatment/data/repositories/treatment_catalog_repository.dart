import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/patient_treatment.dart';
import '../models/treatment_catalog_item.dart';

class TreatmentCatalogRepository {
  TreatmentCatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _catalogRef =>
      _db.collection(FirestorePaths.treatmentCatalog);

  Stream<List<TreatmentCatalogItem>> watchActiveCatalog() {
    return _catalogRef.where('active', isEqualTo: true).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => TreatmentCatalogItem.fromJson(doc.data(), id: doc.id))
          .toList();
      items.sort((a, b) {
        if (a.isSystemDefault != b.isSystemDefault) return a.isSystemDefault ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  Future<TreatmentCatalogItem?> findByNormalizedName(String normalizedName) async {
    final clean = normalizeCatalogName(normalizedName);
    if (clean.isEmpty) return null;

    final snapshot = await _catalogRef.where('normalizedName', isEqualTo: clean).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TreatmentCatalogItem.fromJson(doc.data(), id: doc.id);
  }

  Future<TreatmentCatalogItem> ensureCustomTreatmentExists({
    required String displayName,
    required String category,
    required String createdBy,
  }) async {
    final normalized = normalizeCatalogName(displayName);
    final cleanName = normalizeHumanName(displayName);
    if (normalized.isEmpty || cleanName.isEmpty) {
      throw Exception('TREATMENT_CATALOG_NAME_REQUIRED');
    }

    final existing = await findByNormalizedName(normalized);
    if (existing != null) return existing;

    final docRef = _catalogRef.doc(normalized);
    final item = TreatmentCatalogItem(
      id: docRef.id,
      name: cleanName,
      normalizedName: normalized,
      category: category.trim().isEmpty ? 'ortodoncia' : category.trim().toLowerCase(),
      baseType: normalized,
      requiresSubtype: false,
      allowedSubtypes: const <String>[],
      isSystemDefault: false,
      active: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await docRef.set(item.toJson(), SetOptions(merge: true));
    return item;
  }

  static String normalizeCatalogName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  static String normalizeHumanName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    return clean
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => PatientTreatment.labelForBaseTreatment(word))
        .join(' ');
  }
}
