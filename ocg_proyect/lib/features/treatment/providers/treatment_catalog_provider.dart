import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/treatment_catalog_item.dart';
import '../data/repositories/treatment_catalog_repository.dart';

final treatmentCatalogRepositoryProvider = Provider<TreatmentCatalogRepository>((ref) {
  return TreatmentCatalogRepository(FirebaseFirestore.instance);
});

final treatmentCatalogProvider = StreamProvider<List<TreatmentCatalogItem>>((ref) {
  return ref.watch(treatmentCatalogRepositoryProvider).watchActiveCatalog();
});
