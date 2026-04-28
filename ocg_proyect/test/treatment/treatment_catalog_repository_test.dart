import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/treatment/data/repositories/treatment_catalog_repository.dart';

void main() {
  group('TreatmentCatalogRepository', () {
    late FakeFirebaseFirestore db;
    late TreatmentCatalogRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = TreatmentCatalogRepository(db);
    });

    test('crea tratamiento global custom normalizado', () async {
      final item = await repo.createCatalogItem(
        name: 'Brackets Estéticos',
        category: 'Ortodoncia',
        baseType: 'Brackets Estéticos',
        requiresSubtype: false,
        allowedSubtypes: const [],
        createdBy: 'admin-1',
      );

      expect(item.id, 'brackets_estéticos');
      expect(item.name, 'Brackets Estéticos');
      expect(item.baseType, 'brackets_estéticos');

      final doc = await db.collection('treatmentCatalog').doc(item.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['createdBy'], 'admin-1');
    });

    test('si ya existe un tratamiento normalizado no lo duplica', () async {
      final first = await repo.createCatalogItem(
        name: 'Obturación',
        category: 'General',
        baseType: 'Obturación',
        requiresSubtype: false,
        allowedSubtypes: const [],
        createdBy: 'admin-1',
      );
      final second = await repo.createCatalogItem(
        name: '  obturación  ',
        category: 'General',
        baseType: 'Obturación',
        requiresSubtype: false,
        allowedSubtypes: const [],
        createdBy: 'admin-2',
      );

      expect(second.id, first.id);
      final snapshot = await db.collection('treatmentCatalog').get();
      expect(snapshot.docs.length, 1);
    });

    test('rechaza nombres vacíos o con solo espacios', () async {
      expect(
        () => repo.createCatalogItem(
          name: '   ',
          category: 'General',
          baseType: 'General',
          requiresSubtype: false,
          allowedSubtypes: const [],
          createdBy: 'admin-1',
        ),
        throwsA(
          predicate(
            (e) => e is Exception &&
                e.toString().contains('TREATMENT_CATALOG_NAME_REQUIRED'),
          ),
        ),
      );
    });

    test('tratamiento nuevo queda disponible en el catálogo activo global', () async {
      await repo.createCatalogItem(
        name: '  Placa   neuromiorrelajante  ',
        category: 'Oclusión',
        baseType: 'Placa neuromiorrelajante',
        requiresSubtype: false,
        allowedSubtypes: const [],
        createdBy: 'admin-7',
      );

      final items = await repo.watchCatalog().first;
      final created = items.firstWhere(
        (item) => item.id == 'placa_neuromiorrelajante',
      );

      expect(created.name, 'Placa neuromiorrelajante');
      expect(created.normalizedName, 'placa_neuromiorrelajante');
      expect(created.category, 'oclusión');
      expect(created.active, isTrue);
    });
  });
}
