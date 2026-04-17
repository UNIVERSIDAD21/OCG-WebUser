import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/models/financial_item_model.dart';
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
        patientId: 'p1',
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
        createdBy: 'admin-1',
        updatedBy: 'admin-1',
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
      expect(treatmentDoc.data()?['financialSummary']['totalAmount'], 500000);
      expect(treatmentDoc.data()?['financialSummary']['itemsCount'], 3);
      expect(paymentDoc.data()?['totalTratamiento'], 500000);
      expect(paymentDoc.data()?['treatmentId'], 'tx-1');
      expect(patientDoc.data()?['saldoPendiente'], 200000);
    });

    test('replaceFinancialItems escribe conceptos persistentes ligados a patientId y treatmentId', () async {
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(treatment.toJson());

      final items = <FinancialItemModel>[
        FinancialItemModel(
          id: 'initial',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Inicial',
          normalizedName: 'inicial',
          kind: 'initial',
          amount: 300000,
          deletable: false,
          editableName: true,
          order: 1,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
        FinancialItemModel(
          id: 'controls',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Controles',
          normalizedName: 'controles',
          kind: 'controls',
          amount: 450000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
        FinancialItemModel(
          id: 'retainers',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Retenedores',
          normalizedName: 'retenedores',
          kind: 'retainers',
          amount: 150000,
          deletable: true,
          editableName: true,
          order: 3,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ];

      await repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: items);

      final snapshot = await db.collection('patients/p1/treatments/tx-1/financialItems').get();
      final first = snapshot.docs.firstWhere((doc) => doc.id == 'initial').data();
      final summary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];

      expect(snapshot.docs.length, 3);
      expect(first['patientId'], 'p1');
      expect(first['treatmentId'], 'tx-1');
      expect(first['amount'], 300000);
      expect(summary['totalAmount'], 900000);
      expect(summary['pendingAmount'], 600000);
    });
  });
}
