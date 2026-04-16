import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/repositories/treatment_financial_repository.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';

void main() {
  group('TreatmentFinancialRepository', () {
    late FakeFirebaseFirestore db;
    late TreatmentFinancialRepository repo;
    late PatientTreatment treatment;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = TreatmentFinancialRepository(db);
      treatment = PatientTreatment(
        id: 'tx-1',
        nombre: 'Convencional',
        categoria: 'ortodoncia',
        tipoBase: 'convencional',
        subtipo: 'metalico',
        estado: 'activo',
        etapaActual: TreatmentStage.valoracionInicial,
        fechaInicio: DateTime(2026, 4, 1),
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        isPrimary: true,
        totalTratamiento: 1800000,
        saldoPendiente: 1500000,
      );
    });

    test('ensureBaseItems crea obligatorios y legado cuando existe total anterior', () async {
      await repo.ensureBaseItems(patientId: 'p1', treatment: treatment);

      final snap = await db.collection('patients/p1/treatments/tx-1/financialItems').get();
      expect(snap.docs.length, 4);
      expect(snap.docs.any((doc) => doc.id == 'initial'), isTrue);
      expect(snap.docs.any((doc) => doc.id == 'controls'), isTrue);
      expect(snap.docs.any((doc) => doc.id == 'legacy_total'), isTrue);
    });

    test('recalculateSummary actualiza treatment y payments para tratamiento principal', () async {
      await db.collection('payments').doc('p1').set({
        'id': 'p1',
        'patientId': 'p1',
        'createdAt': DateTime(2026, 4, 1),
      });
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(treatment.toJson());

      await repo.ensureBaseItems(patientId: 'p1', treatment: treatment);
      await db.collection('patients/p1/treatments/tx-1/financialItems').doc('initial').update({'amount': 300000});
      await db.collection('patients/p1/treatments/tx-1/financialItems').doc('controls').update({'amount': 200000});
      await db.collection('patients/p1/treatments/tx-1/financialItems').doc('legacy_total').update({'active': false});

      await repo.recalculateSummary(patientId: 'p1', treatment: treatment);

      final treatmentDoc = await db.collection('patients/p1/treatments').doc('tx-1').get();
      final paymentDoc = await db.collection('payments').doc('p1').get();
      final patientDoc = await db.collection('patients').doc('p1').get();

      expect(treatmentDoc.data()?['totalTratamiento'], 500000);
      expect(paymentDoc.data()?['totalTratamiento'], 500000);
      expect(patientDoc.data()?['saldoPendiente'], 200000);
    });
  });
}
