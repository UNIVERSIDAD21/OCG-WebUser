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
      final item = await repo.ensureCustomTreatmentExists(
        displayName: 'Brackets Estéticos',
        category: 'Ortodoncia',
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
      final first = await repo.ensureCustomTreatmentExists(
        displayName: 'Obturación',
        category: 'General',
        createdBy: 'admin-1',
      );
      final second = await repo.ensureCustomTreatmentExists(
        displayName: '  obturación  ',
        category: 'General',
        createdBy: 'admin-2',
      );

      expect(second.id, first.id);
      final snapshot = await db.collection('treatmentCatalog').get();
      expect(snapshot.docs.length, 1);
    });
  });
}
