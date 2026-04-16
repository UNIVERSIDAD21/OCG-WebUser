import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/clinical_files/data/models/clinical_file_model.dart';

void main() {
  test('ClinicalFileModel serializa y deserializa campos clave', () {
    final now = DateTime(2026, 4, 16, 18, 0);
    final model = ClinicalFileModel(
      id: 'file-1',
      patientId: 'patient-1',
      treatmentId: 'tx-1',
      treatmentNameSnapshot: 'Convencional · Metálico',
      originalName: 'panorex.pdf',
      displayName: 'Radiografía panorámica inicial',
      storagePath: 'patients/patient-1/clinical-files/file-1_panorex.pdf',
      downloadUrl: 'https://example.com/file.pdf',
      mimeType: 'application/pdf',
      extension: 'pdf',
      sizeBytes: 2000,
      category: 'radiografia',
      notes: 'Antes de iniciar tratamiento',
      uploadedBy: 'admin-1',
      uploadedAt: now,
      updatedAt: now,
      active: true,
      visibleToPatient: false,
    );

    final json = model.toJson();
    final restored = ClinicalFileModel.fromJson(json, id: 'file-1');

    expect(restored.id, 'file-1');
    expect(restored.treatmentId, 'tx-1');
    expect(restored.category, 'radiografia');
    expect(restored.mimeType, 'application/pdf');
    expect(restored.isPdf, isTrue);
  });
}
