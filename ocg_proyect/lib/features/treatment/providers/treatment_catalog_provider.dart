import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/treatment_catalog_item.dart';
import '../data/repositories/treatment_catalog_repository.dart';

final treatmentCatalogRepositoryProvider = Provider<TreatmentCatalogRepository>(
  (ref) {
    return TreatmentCatalogRepository(FirebaseFirestore.instance);
  },
);

final treatmentCatalogProvider = StreamProvider<List<TreatmentCatalogItem>>((
  ref,
) {
  return ref.watch(treatmentCatalogRepositoryProvider).watchCatalog();
});

final createTreatmentCatalogItemProvider =
    Provider<
      Future<TreatmentCatalogItem> Function({
        required String name,
        required String category,
        required String baseType,
        required bool requiresSubtype,
        required List<String> allowedSubtypes,
        String? createdBy,
      })
    >((ref) {
      final repository = ref.watch(treatmentCatalogRepositoryProvider);
      return ({
        required String name,
        required String category,
        required String baseType,
        required bool requiresSubtype,
        required List<String> allowedSubtypes,
        String? createdBy,
      }) => repository.createCatalogItem(
        name: name,
        category: category,
        baseType: baseType,
        requiresSubtype: requiresSubtype,
        allowedSubtypes: allowedSubtypes,
        createdBy: createdBy,
      );
    });
