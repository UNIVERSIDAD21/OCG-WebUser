import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';
import 'package:ocg_proyect/features/treatment/data/repositories/patient_treatments_repository.dart';

void main() {
  group('PatientTreatmentsRepository', () {
    late FakeFirebaseFirestore db;
    late PatientTreatmentsRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = PatientTreatmentsRepository(db);
    });

    test('guarda tratamiento principal y sincroniza paciente y payments', () async {
      final treatment = PatientTreatment(
        id: 'tx-1',
        patientId: 'patient-1',
        nombre: 'Convencional',
        categoria: 'ortodoncia',
        tipoBase: 'convencional',
        subtipo: 'metalico',
        estado: 'activo',
        etapaActual: TreatmentStage.valoracionInicial,
        fechaInicio: DateTime(2026, 4, 16),
        createdAt: DateTime(2026, 4, 16),
        updatedAt: DateTime(2026, 4, 16),
        isPrimary: true,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
        totalTratamiento: 2500000,
        saldoPendiente: 1500000,
        notas: 'Tratamiento principal del paciente',
      );

      await repo.saveTreatment(patientId: 'patient-1', treatment: treatment);

      final patientDoc = await db.collection('patients').doc('patient-1').get();
      final paymentDoc = await db.collection('payments').doc('patient-1').get();
      final treatmentDoc = await db.collection('patients/patient-1/treatments').doc('tx-1').get();

      expect(treatmentDoc.exists, isTrue);
      expect(treatmentDoc.data()?['id'], 'tx-1');
      expect(treatmentDoc.data()?['patientId'], 'patient-1');
      expect(treatmentDoc.data()?['name'], 'Convencional');
      expect(treatmentDoc.data()?['baseType'], 'convencional');
      expect(treatmentDoc.data()?['subtype'], 'metalico');
      expect(treatmentDoc.data()?['currentStageId'], 'valoracionInicial');
      expect(treatmentDoc.data()?['currentStageName'], 'Valoración inicial');
      expect(patientDoc.data()?['primaryTreatmentId'], 'tx-1');
      expect(patientDoc.data()?['tipoTratamiento'], 'convencional');
      expect(paymentDoc.data()?['totalTratamiento'], 2500000);
      expect(paymentDoc.data()?['saldoPendiente'], 1500000);
      expect(paymentDoc.data()?['montoPagado'], 1000000);
    });

    test('cambia tratamiento principal y desmarca el anterior', () async {
      final first = PatientTreatment(
        id: 'tx-1',
        patientId: 'patient-1',
        nombre: 'Convencional',
        categoria: 'ortodoncia',
        tipoBase: 'convencional',
        subtipo: 'metalico',
        estado: 'activo',
        etapaActual: TreatmentStage.valoracionInicial,
        fechaInicio: DateTime(2026, 4, 16),
        createdAt: DateTime(2026, 4, 16),
        updatedAt: DateTime(2026, 4, 16),
        isPrimary: true,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
      );
      final second = PatientTreatment(
        id: 'tx-2',
        patientId: 'patient-1',
        nombre: 'Alineadores',
        categoria: 'ortodoncia',
        tipoBase: 'alineadores',
        estado: 'activo',
        etapaActual: TreatmentStage.estudioPlaneacion,
        fechaInicio: DateTime(2026, 4, 20),
        createdAt: DateTime(2026, 4, 20),
        updatedAt: DateTime(2026, 4, 20),
        isPrimary: false,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
      );

      await repo.saveTreatment(patientId: 'patient-1', treatment: first);
      await repo.saveTreatment(patientId: 'patient-1', treatment: second);
      await repo.setPrimaryTreatment(
        patientId: 'patient-1',
        treatment: second.copyWith(isPrimary: true),
      );

      final firstDoc = await db.collection('patients/patient-1/treatments').doc('tx-1').get();
      final secondDoc = await db.collection('patients/patient-1/treatments').doc('tx-2').get();
      final patientDoc = await db.collection('patients').doc('patient-1').get();

      expect(firstDoc.data()?['isPrimary'], isFalse);
      expect(secondDoc.data()?['isPrimary'], isTrue);
      expect(patientDoc.data()?['primaryTreatmentId'], 'tx-2');
    });

    test('permite coexistencia de segundo y tercer tratamiento sin sobrescribir', () async {
      final first = PatientTreatment(
        id: 'tx-1',
        patientId: 'patient-1',
        nombre: 'Convencional',
        categoria: 'ortodoncia',
        tipoBase: 'convencional',
        subtipo: 'metalico',
        estado: 'activo',
        etapaActual: TreatmentStage.valoracionInicial,
        fechaInicio: DateTime(2026, 4, 16),
        createdAt: DateTime(2026, 4, 16),
        updatedAt: DateTime(2026, 4, 16),
        isPrimary: true,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
      );
      final second = PatientTreatment(
        id: 'tx-2',
        patientId: 'patient-1',
        nombre: 'Alineadores',
        categoria: 'ortodoncia',
        tipoBase: 'alineadores',
        estado: 'activo',
        etapaActual: TreatmentStage.estudioPlaneacion,
        fechaInicio: DateTime(2026, 4, 20),
        createdAt: DateTime(2026, 4, 20),
        updatedAt: DateTime(2026, 4, 20),
        isPrimary: false,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
      );
      final third = PatientTreatment(
        id: 'tx-3',
        patientId: 'patient-1',
        nombre: 'Retenedores',
        categoria: 'ortodoncia',
        tipoBase: 'retenedores',
        estado: 'pausado',
        etapaActual: TreatmentStage.retencion,
        fechaInicio: DateTime(2026, 4, 25),
        createdAt: DateTime(2026, 4, 25),
        updatedAt: DateTime(2026, 4, 25),
        isPrimary: false,
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
      );

      await repo.saveTreatment(patientId: 'patient-1', treatment: first);
      await repo.saveTreatment(patientId: 'patient-1', treatment: second);
      await repo.saveTreatment(patientId: 'patient-1', treatment: third);

      final snapshot = await db.collection('patients/patient-1/treatments').get();
      final ids = snapshot.docs.map((doc) => doc.id).toSet();

      expect(snapshot.docs.length, 3);
      expect(ids, containsAll(<String>{'tx-1', 'tx-2', 'tx-3'}));
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-1').data()['name'], 'Convencional');
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-2').data()['name'], 'Alineadores');
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-3').data()['name'], 'Retenedores');
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-1').data()['isPrimary'], isTrue);
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-2').data()['isPrimary'], isFalse);
      expect(snapshot.docs.firstWhere((doc) => doc.id == 'tx-3').data()['isPrimary'], isFalse);
    });
  });
}
