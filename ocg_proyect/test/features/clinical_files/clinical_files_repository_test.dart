import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/clinical_files/data/models/clinical_file_model.dart';
import 'package:ocg_proyect/features/clinical_files/data/repositories/clinical_files_repository.dart';

void main() {
  group('ClinicalFilesRepository', () {
    late FakeFirebaseFirestore db;
    late ClinicalFilesRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = ClinicalFilesRepository(db);
    });

    test('watchFiles filtra por treatmentId y visibilidad activa', () async {
      final base = ClinicalFileModel(
        id: 'f1',
        patientId: 'p1',
        treatmentId: 'tx-1',
        originalName: 'a.pdf',
        displayName: 'A',
        storagePath: 'x',
        mimeType: 'application/pdf',
        extension: 'pdf',
        sizeBytes: 100,
        category: 'pdf_clinico',
        uploadedBy: 'admin',
        uploadedAt: DateTime(2026, 4, 16),
        updatedAt: DateTime(2026, 4, 16),
        active: true,
      );

      await repo.saveMetadata(base);
      await repo.saveMetadata(base.copyWith(
        id: 'f2',
        treatmentId: 'tx-2',
        visibleToPatient: true,
      ));
      await repo.saveMetadata(base.copyWith(
        id: 'f3',
        active: false,
      ));

      final tx1 = await repo.watchFiles('p1', treatmentId: 'tx-1').first;
      final visible = await repo.watchFiles('p1', onlyVisibleToPatient: true).first;

      expect(tx1.length, 1);
      expect(tx1.first.id, 'f1');
      expect(visible.length, 1);
      expect(visible.first.id, 'f2');
    });

    test('softDelete desactiva el archivo y registra auditoría', () async {
      final file = ClinicalFileModel(
        id: 'f1',
        patientId: 'p1',
        originalName: 'a.pdf',
        displayName: 'A',
        storagePath: 'x',
        mimeType: 'application/pdf',
        extension: 'pdf',
        sizeBytes: 100,
        category: 'pdf_clinico',
        uploadedBy: 'admin',
        uploadedAt: DateTime(2026, 4, 16),
        updatedAt: DateTime(2026, 4, 16),
        active: true,
      );
      await repo.saveMetadata(file);

      await repo.softDelete(patientId: 'p1', fileId: 'f1', deletedBy: 'admin-2');
      final doc = await db.collection('patients/p1/clinicalFiles').doc('f1').get();
      expect(doc.data()?['active'], isFalse);
      expect(doc.data()?['deletedBy'], 'admin-2');
    });
  });
}
