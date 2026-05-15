import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/clinical_files/data/models/clinical_file_model.dart';
import 'package:ocg_proyect/features/consultation/data/models/consultation_model.dart';
import 'package:ocg_proyect/features/consultation/data/repositories/consultation_repository.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/shared/constants/firestore_paths.dart';

void main() {
  group('ConsultationRepository.saveCompletedConsultation', () {
    test(
      'guarda dictamen e historial en tratamiento secundario sin espejo general',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = ConsultationRepository(db);
        const patientId = 'patient-1';
        const treatmentId = 'tx-secondary';
        final now = DateTime(2026, 5, 15, 11, 0);

        await db.collection(FirestorePaths.patients).doc(patientId).set({
          'id': patientId,
          'etapaActual': TreatmentStage.valoracionInicial.name,
        });
        await db
            .doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId))
            .set({
              'id': treatmentId,
              'patientId': patientId,
              'isPrimary': false,
              'etapaActual': TreatmentStage.estudioPlaneacion.name,
              'currentStageId': TreatmentStage.estudioPlaneacion.name,
            });

        final consultation = ConsultationModel(
          id: 'consult-1',
          patientId: patientId,
          patientName: 'Paciente Uno',
          appointmentId: 'synthetic-appt',
          treatmentId: treatmentId,
          treatmentNameSnapshot: 'Alineadores',
          stageId: TreatmentStage.estudioPlaneacion,
          stageNameSnapshot: 'Estudio y planeacion',
          doctorId: 'admin-1',
          doctorName: 'Doctora',
          date: now,
          clinicalNotes: 'Paciente apto para iniciar alineadores.',
          signatureUrl: 'https://example.com/signature.png',
          signatureCapturedAt: now,
          status: ConsultationStatus.completed,
          createdAt: now,
          updatedAt: now,
        );

        final clinicalFile = _clinicalFile(
          id: 'consult-1-doc-1',
          patientId: patientId,
          treatmentId: treatmentId,
          consultationId: 'consult-1',
          sourceType: 'consultation_attachment',
          sourceId: 'consult-1',
          treatmentNameSnapshot: 'Alineadores',
          stageId: TreatmentStage.estudioPlaneacion.name,
          stageNameSnapshot: 'Estudio y planeacion',
          now: now,
        );

        await repo.saveCompletedConsultation(
          consultation: consultation,
          clinicalFiles: [clinicalFile],
          appointmentId: '',
          currentStage: TreatmentStage.estudioPlaneacion,
          resultingStage: TreatmentStage.instalacion,
          stageSummary: 'Dictamen de avance para tratamiento secundario.',
          actorId: 'admin-1',
          advancePhase: true,
          treatmentId: treatmentId,
          treatmentIsPrimary: false,
          nextStagePlan: 'Iniciar instalacion.',
          attachmentsSummary: 'Foto clinica inicial.',
        );

        final consultationDoc = await db
            .collection('patients/$patientId/consultations')
            .doc('consult-1')
            .get();
        final treatmentHistory = await db
            .collection(
              FirestorePaths.treatmentStageHistory(patientId, treatmentId),
            )
            .get();
        final generalHistory = await db
            .collection(FirestorePaths.stageHistory(patientId))
            .get();
        final fileDoc = await db
            .collection(FirestorePaths.patientClinicalFiles(patientId))
            .doc('consult-1-doc-1')
            .get();

        expect(consultationDoc.data()?['treatmentId'], treatmentId);
        expect(
          consultationDoc.data()?['stageId'],
          TreatmentStage.estudioPlaneacion.name,
        );
        expect(consultationDoc.data()?['clinicalFileIds'], ['consult-1-doc-1']);
        expect(treatmentHistory.docs.length, 1);
        expect(treatmentHistory.docs.first.data()['treatmentId'], treatmentId);
        expect(
          treatmentHistory.docs.first.data()['consultationId'],
          'consult-1',
        );
        expect(
          treatmentHistory.docs.first.data()['signatureUrl'],
          'https://example.com/signature.png',
        );
        expect(treatmentHistory.docs.first.data()['fechaEfectiva'], isNotNull);
        expect(generalHistory.docs, isEmpty);
        expect(fileDoc.data()?['consultationId'], 'consult-1');
        expect(fileDoc.data()?['sourceType'], 'consultation_attachment');
      },
    );

    test(
      'normaliza archivos del dictamen y no actualiza citas sinteticas',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = ConsultationRepository(db);
        const patientId = 'patient-1';
        const treatmentId = 'tx-primary';
        final now = DateTime(2026, 5, 15, 12, 0);

        await db.collection(FirestorePaths.patients).doc(patientId).set({
          'id': patientId,
          'etapaActual': TreatmentStage.controles.name,
        });
        await db
            .doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId))
            .set({
              'id': treatmentId,
              'patientId': patientId,
              'isPrimary': true,
              'etapaActual': TreatmentStage.controles.name,
              'currentStageId': TreatmentStage.controles.name,
            });

        final consultation = ConsultationModel(
          id: 'consult-2',
          patientId: patientId,
          patientName: 'Paciente Uno',
          appointmentId: 'dictamen-patient-1-123',
          treatmentId: treatmentId,
          treatmentNameSnapshot: 'Convencional - Metalico',
          stageId: TreatmentStage.controles,
          stageNameSnapshot: 'Controles',
          doctorId: 'admin-1',
          doctorName: 'Doctora',
          date: now,
          clinicalNotes: 'Control con adjunto incompleto.',
          signatureUrl: 'https://example.com/signature.png',
          signatureCapturedAt: now,
          status: ConsultationStatus.completed,
          createdAt: now,
          updatedAt: now,
        );

        final clinicalFile = _clinicalFile(
          id: ' consult-2-doc-1 ',
          patientId: patientId,
          now: now,
        );

        await repo.saveCompletedConsultation(
          consultation: consultation,
          clinicalFiles: [clinicalFile],
          appointmentId: 'dictamen-patient-1-123',
          currentStage: TreatmentStage.controles,
          resultingStage: TreatmentStage.controles,
          stageSummary: 'Control sin avance.',
          actorId: 'admin-1',
          advancePhase: false,
          treatmentId: treatmentId,
          treatmentIsPrimary: true,
          attachmentsSummary: 'Foto clinica.',
        );

        final consultationDoc = await db
            .collection('patients/$patientId/consultations')
            .doc('consult-2')
            .get();
        final fileDoc = await db
            .collection(FirestorePaths.patientClinicalFiles(patientId))
            .doc('consult-2-doc-1')
            .get();
        final syntheticAppointmentDoc = await db
            .collection(FirestorePaths.appointments)
            .doc('dictamen-patient-1-123')
            .get();
        final generalHistory = await db
            .collection(FirestorePaths.stageHistory(patientId))
            .get();

        expect(consultationDoc.data()?['clinicalFileIds'], ['consult-2-doc-1']);
        expect(fileDoc.data()?['consultationId'], 'consult-2');
        expect(fileDoc.data()?['sourceType'], 'consultation_attachment');
        expect(fileDoc.data()?['sourceId'], 'consult-2');
        expect(fileDoc.data()?['treatmentId'], treatmentId);
        expect(
          fileDoc.data()?['treatmentNameSnapshot'],
          'Convencional - Metalico',
        );
        expect(fileDoc.data()?['stageId'], TreatmentStage.controles.name);
        expect(fileDoc.data()?['stageNameSnapshot'], 'Controles');
        expect(syntheticAppointmentDoc.exists, isFalse);
        expect(
          generalHistory.docs.single.data()['consultationId'],
          'consult-2',
        );
      },
    );

    test('actualiza cita real con trazabilidad del dictamen', () async {
      final db = FakeFirebaseFirestore();
      final repo = ConsultationRepository(db);
      const patientId = 'patient-1';
      const appointmentId = 'appt-1';
      const treatmentId = 'tx-primary';
      final now = DateTime(2026, 5, 15, 13, 0);

      await db.collection(FirestorePaths.patients).doc(patientId).set({
        'id': patientId,
        'etapaActual': TreatmentStage.valoracionInicial.name,
      });
      await db.collection(FirestorePaths.appointments).doc(appointmentId).set({
        'id': appointmentId,
        'patientId': patientId,
        'estado': AppointmentStatus.programada.name,
      });

      final consultation = ConsultationModel(
        id: 'consult-3',
        patientId: patientId,
        patientName: 'Paciente Uno',
        appointmentId: appointmentId,
        treatmentId: treatmentId,
        treatmentNameSnapshot: 'Alineadores',
        stageId: TreatmentStage.estudioPlaneacion,
        stageNameSnapshot: 'Estudio y planeacion',
        doctorId: 'admin-1',
        doctorName: 'Doctora',
        date: now,
        clinicalNotes: 'Dictamen desde cita real.',
        status: ConsultationStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveCompletedConsultation(
        consultation: consultation,
        clinicalFiles: const [],
        appointmentId: appointmentId,
        currentStage: TreatmentStage.estudioPlaneacion,
        resultingStage: TreatmentStage.estudioPlaneacion,
        stageSummary: 'Dictamen desde cita real.',
        actorId: 'admin-1',
        advancePhase: false,
        treatmentId: treatmentId,
        treatmentIsPrimary: false,
      );

      final appointmentDoc = await db
          .collection(FirestorePaths.appointments)
          .doc(appointmentId)
          .get();

      expect(
        appointmentDoc.data()?['estado'],
        AppointmentStatus.completada.name,
      );
      expect(appointmentDoc.data()?['consultationId'], 'consult-3');
      expect(appointmentDoc.data()?['treatmentId'], treatmentId);
      expect(appointmentDoc.data()?['treatmentNameSnapshot'], 'Alineadores');
      expect(
        appointmentDoc.data()?['stageId'],
        TreatmentStage.estudioPlaneacion.name,
      );
    });
  });
}

ClinicalFileModel _clinicalFile({
  required String id,
  required String patientId,
  required DateTime now,
  String? treatmentId,
  String? consultationId,
  String? sourceType,
  String? sourceId,
  String? treatmentNameSnapshot,
  String? stageId,
  String? stageNameSnapshot,
}) {
  return ClinicalFileModel(
    id: id,
    patientId: patientId,
    treatmentId: treatmentId,
    consultationId: consultationId,
    sourceType: sourceType,
    sourceId: sourceId,
    treatmentNameSnapshot: treatmentNameSnapshot,
    stageId: stageId,
    stageNameSnapshot: stageNameSnapshot,
    originalName: 'foto-inicial.jpg',
    displayName: 'foto-inicial.jpg',
    storagePath: 'patients/$patientId/clinical-files/foto.jpg',
    downloadUrl: 'https://example.com/foto.jpg',
    mimeType: 'image/jpeg',
    extension: 'jpg',
    sizeBytes: 1200,
    category: 'foto_clinica',
    uploadedBy: 'admin-1',
    uploadedAt: now,
    updatedAt: now,
    active: true,
  );
}
