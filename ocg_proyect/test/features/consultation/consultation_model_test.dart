import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/consultation/data/models/consultation_model.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';

void main() {
  group('ConsultationModel', () {
    test(
      'serializa contrato de tratamiento, etapa y PDF sin romper legacy',
      () {
        final now = DateTime(2026, 5, 15, 10, 30);
        final appointmentDate = DateTime(2026, 5, 15, 9, 0);
        final model = ConsultationModel(
          id: 'consult-1',
          patientId: 'patient-1',
          patientName: 'Paciente Uno',
          appointmentId: 'appt-1',
          appointmentDate: appointmentDate,
          treatmentId: 'tx-2',
          treatmentNameSnapshot: 'Alineadores',
          stageId: TreatmentStage.estudioPlaneacion,
          stageNameSnapshot: 'Estudio y planeacion',
          doctorId: 'admin-1',
          doctorName: 'Doctora',
          date: now,
          clinicalNotes: 'Notas clinicas del dictamen.',
          signatureUrl: 'https://example.com/signature.png',
          signatureCapturedAt: now,
          reportPdfFileId: 'pdf-1',
          reportPdfUrl: 'https://example.com/dictamen.pdf',
          status: ConsultationStatus.completed,
          createdAt: now,
          updatedAt: now,
        );

        final json = model.toJson();
        final restored = ConsultationModel.fromJson(json, id: 'consult-1');

        expect(json['treatmentId'], 'tx-2');
        expect(json['appointmentDate'], isA<Timestamp>());
        expect(json['treatmentNameSnapshot'], 'Alineadores');
        expect(json['stageId'], TreatmentStage.estudioPlaneacion.name);
        expect(json['stageNameSnapshot'], 'Estudio y planeacion');
        expect(json['reportPdfFileId'], 'pdf-1');
        expect(json['reportPdfUrl'], 'https://example.com/dictamen.pdf');
        expect(restored.treatmentId, 'tx-2');
        expect(restored.appointmentDate, appointmentDate);
        expect(restored.stageId, TreatmentStage.estudioPlaneacion);
        expect(restored.reportPdfFileId, 'pdf-1');

        final legacy = ConsultationModel.fromJson({
          'id': 'legacy-consult',
          'patientId': 'patient-1',
          'patientName': 'Paciente Uno',
          'doctorId': 'admin-1',
          'doctorName': 'Doctora',
          'date': Timestamp.fromDate(now),
        });

        expect(legacy.treatmentId, isNull);
        expect(legacy.stageId, isNull);
        expect(legacy.reportPdfUrl, isNull);
      },
    );
  });
}
