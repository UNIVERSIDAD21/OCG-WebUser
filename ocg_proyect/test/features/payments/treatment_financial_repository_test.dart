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

    test('ensureBaseItems crea Inicial + Controles + Retenedores para tratamiento no Ortopedia', () async {
      final nonOrthopedics = treatment.copyWith(
        totalTratamiento: 0,
        saldoPendiente: 0,
      );

      await repo.ensureBaseItems(patientId: 'p1', treatment: nonOrthopedics);

      final snap = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();
      final ids = snap.docs.map((doc) => doc.id).toList();
      final initial = snap.docs.firstWhere((doc) => doc.id == 'initial').data();
      final controls = snap.docs.firstWhere((doc) => doc.id == 'controls').data();
      final retainers = snap.docs.firstWhere((doc) => doc.id == 'retainers').data();

      expect(snap.docs.length, 3);
      expect(ids, ['initial', 'controls', 'retainers']);
      expect(ids.contains('appliance_1'), isFalse);
      expect(initial['patientId'], 'p1');
      expect(initial['treatmentId'], 'tx-1');
      expect(initial['name'], 'Inicial');
      expect(initial['deletable'], isFalse);
      expect(controls['name'], 'Controles');
      expect(controls['deletable'], isFalse);
      expect(retainers['name'], 'Retenedores');
      expect(retainers['kind'], 'retainers');
      expect(retainers['deletable'], isTrue);
      expect(retainers['editableName'], isTrue);

      final reloaded = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();
      expect(reloaded.docs.map((doc) => doc.id).toList(), ['initial', 'controls', 'retainers']);
    });

    test('ensureBaseItems crea Inicial + Controles + Aparato 1 para tratamiento Ortopedia', () async {
      final orthopedics = treatment.copyWith(
        id: 'tx-ortopedia',
        tipoBase: 'ortopedia',
        nombre: 'Ortopedia',
        totalTratamiento: 0,
        saldoPendiente: 0,
      );

      await repo.ensureBaseItems(patientId: 'p1', treatment: orthopedics);

      final snap = await db.collection('patients/p1/treatments/tx-ortopedia/financialItems').orderBy('order').get();
      final ids = snap.docs.map((doc) => doc.id).toList();
      final appliance = snap.docs.firstWhere((doc) => doc.id == 'appliance_1').data();

      expect(snap.docs.length, 3);
      expect(ids, ['initial', 'controls', 'appliance_1']);
      expect(ids.contains('retainers'), isFalse);
      expect(appliance['patientId'], 'p1');
      expect(appliance['treatmentId'], 'tx-ortopedia');
      expect(appliance['name'], 'Aparato 1');
      expect(appliance['kind'], 'appliance');
      expect(appliance['deletable'], isTrue);
      expect(appliance['editableName'], isTrue);
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

    test('financialSummary totalAmount se calcula desde conceptos activos y se actualiza al editar/desactivar', () async {
      await db.collection('payments').doc('p1').set({
        'id': 'p1',
        'patientId': 'p1',
        'createdAt': DateTime(2026, 4, 1),
      });
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
          amount: 100000,
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
          amount: 250000,
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
          amount: 50000,
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

      final firstSummary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];
      expect(firstSummary['totalAmount'], 400000);
      expect(firstSummary['subtotalAmount'], 400000);
      expect(firstSummary['itemsCount'], 3);

      final updatedItems = <FinancialItemModel>[
        items[0],
        items[1].copyWith(amount: 300000, updatedAt: DateTime(2026, 4, 2)),
        items[2].copyWith(active: false, updatedAt: DateTime(2026, 4, 2)),
      ];

      await repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: updatedItems);

      final treatmentDoc = await db.collection('patients/p1/treatments').doc('tx-1').get();
      final secondSummary = treatmentDoc.data()?['financialSummary'];
      final reloadedItems = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();

      expect(secondSummary['totalAmount'], 400000);
      expect(secondSummary['subtotalAmount'], 400000);
      expect(secondSummary['itemsCount'], 2);
      expect(reloadedItems.docs.firstWhere((doc) => doc.id == 'controls').data()['amount'], 300000);
      expect(reloadedItems.docs.firstWhere((doc) => doc.id == 'retainers').data()['active'], isFalse);
    });

    test('permite editar nombre y monto de Inicial y Controles y recalcula el total', () async {
      await db.collection('payments').doc('p1').set({
        'id': 'p1',
        'patientId': 'p1',
        'createdAt': DateTime(2026, 4, 1),
      });
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(treatment.toJson());

      final items = <FinancialItemModel>[
        FinancialItemModel(
          id: 'initial',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Inicial clínica',
          normalizedName: 'inicial_clínica',
          kind: 'initial',
          amount: 350000,
          deletable: false,
          editableName: true,
          order: 1,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 2),
        ),
        FinancialItemModel(
          id: 'controls',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Controles mensuales',
          normalizedName: 'controles_mensuales',
          kind: 'controls',
          amount: 450000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 2),
        ),
        FinancialItemModel(
          id: 'retainers',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Retenedores',
          normalizedName: 'retenedores',
          kind: 'retainers',
          amount: 100000,
          deletable: true,
          editableName: true,
          order: 3,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 2),
        ),
      ];

      await repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: items);

      final snapshot = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();
      final initial = snapshot.docs.firstWhere((doc) => doc.id == 'initial').data();
      final controls = snapshot.docs.firstWhere((doc) => doc.id == 'controls').data();
      final summary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];

      expect(initial['name'], 'Inicial clínica');
      expect(initial['amount'], 350000);
      expect(controls['name'], 'Controles mensuales');
      expect(controls['amount'], 450000);
      expect(summary['totalAmount'], 900000);
    });

    test('bloquea eliminar Inicial y Controles por ausencia en la estructura final', () async {
      final itemsWithoutInitial = <FinancialItemModel>[
        FinancialItemModel(
          id: 'controls',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Controles',
          normalizedName: 'controles',
          kind: 'controls',
          amount: 200000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ];

      expect(
        () => repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: itemsWithoutInitial),
        throwsA(predicate((e) => e is Exception && e.toString().contains('REQUIRED_FINANCIAL_ITEMS_MISSING'))),
      );
    });

    test('bloquea nombre vacío y monto negativo en conceptos obligatorios', () async {
      final itemsWithEmptyName = <FinancialItemModel>[
        FinancialItemModel(
          id: 'initial',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: ' ',
          normalizedName: '',
          kind: 'initial',
          amount: 100000,
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
          amount: 100000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ];

      final itemsWithNegativeAmount = <FinancialItemModel>[
        FinancialItemModel(
          id: 'initial',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Inicial',
          normalizedName: 'inicial',
          kind: 'initial',
          amount: -1,
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
          amount: 100000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ];

      expect(
        () => repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: itemsWithEmptyName),
        throwsA(predicate((e) => e is Exception && e.toString().contains('FINANCIAL_ITEM_NAME_REQUIRED'))),
      );
      expect(
        () => repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: itemsWithNegativeAmount),
        throwsA(predicate((e) => e is Exception && e.toString().contains('FINANCIAL_ITEM_NEGATIVE_AMOUNT'))),
      );
    });

    test('permite conceptos extra, edición y desactivación lógica con impacto en total', () async {
      await db.collection('payments').doc('p1').set({
        'id': 'p1',
        'patientId': 'p1',
        'createdAt': DateTime(2026, 4, 1),
      });
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(treatment.toJson());

      final baseWithExtra = <FinancialItemModel>[
        FinancialItemModel(
          id: 'initial',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Inicial',
          normalizedName: 'inicial',
          kind: 'initial',
          amount: 200000,
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
          amount: 300000,
          deletable: false,
          editableName: true,
          order: 2,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
        FinancialItemModel(
          id: 'extra_lab',
          patientId: 'p1',
          treatmentId: 'tx-1',
          name: 'Laboratorio extra',
          normalizedName: 'laboratorio_extra',
          kind: 'extra',
          amount: 120000,
          deletable: true,
          editableName: true,
          order: 3,
          active: true,
          createdByAdmin: true,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ];

      await repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: baseWithExtra);

      final firstSummary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];
      expect(firstSummary['totalAmount'], 620000);
      expect(firstSummary['itemsCount'], 3);

      final editedExtra = baseWithExtra[2].copyWith(
        name: 'Laboratorio premium',
        normalizedName: 'laboratorio_premium',
        amount: 180000,
        updatedAt: DateTime(2026, 4, 2),
      );

      await repo.replaceFinancialItems(
        patientId: 'p1',
        treatment: treatment,
        items: <FinancialItemModel>[baseWithExtra[0], baseWithExtra[1], editedExtra],
      );

      final secondSummary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];
      final editedDoc = await db.collection('patients/p1/treatments/tx-1/financialItems').doc('extra_lab').get();

      expect(editedDoc.data()?['name'], 'Laboratorio premium');
      expect(editedDoc.data()?['amount'], 180000);
      expect(secondSummary['totalAmount'], 680000);

      final disabledExtra = editedExtra.copyWith(active: false, updatedAt: DateTime(2026, 4, 3));
      await repo.replaceFinancialItems(
        patientId: 'p1',
        treatment: treatment,
        items: <FinancialItemModel>[baseWithExtra[0], baseWithExtra[1], disabledExtra],
      );

      final thirdSummary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];
      final disabledDoc = await db.collection('patients/p1/treatments/tx-1/financialItems').doc('extra_lab').get();

      expect(disabledDoc.data()?['active'], isFalse);
      expect(thirdSummary['totalAmount'], 500000);
      expect(thirdSummary['itemsCount'], 2);
    });

    test('convierte Retenedores a Aparato 1 al pasar a Ortopedia sin perder el total', () async {
      await db.collection('payments').doc('p1').set({'id': 'p1', 'patientId': 'p1', 'createdAt': DateTime(2026, 4, 1)});
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(treatment.toJson());

      final items = <FinancialItemModel>[
        FinancialItemModel(id: 'initial', patientId: 'p1', treatmentId: 'tx-1', name: 'Inicial', normalizedName: 'inicial', kind: 'initial', amount: 100000, deletable: false, editableName: true, order: 1, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
        FinancialItemModel(id: 'controls', patientId: 'p1', treatmentId: 'tx-1', name: 'Controles', normalizedName: 'controles', kind: 'controls', amount: 200000, deletable: false, editableName: true, order: 2, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
        FinancialItemModel(id: 'retainers', patientId: 'p1', treatmentId: 'tx-1', name: 'Retenedores', normalizedName: 'retenedores', kind: 'retainers', amount: 300000, deletable: true, editableName: true, order: 3, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
      ];
      await repo.replaceFinancialItems(patientId: 'p1', treatment: treatment, items: items);

      final orthopedicsTreatment = treatment.copyWith(tipoBase: 'ortopedia');
      final converted = await repo.normalizeBaseItemsForTreatmentType(patientId: 'p1', treatment: orthopedicsTreatment);
      await repo.replaceFinancialItems(patientId: 'p1', treatment: orthopedicsTreatment, items: converted);

      final snap = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();
      final ids = snap.docs.map((d) => d.id).toList();
      final appliance = snap.docs.firstWhere((d) => d.id == 'appliance_1').data();
      final summary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];

      expect(ids, ['initial', 'controls', 'appliance_1']);
      expect(ids.contains('retainers'), isFalse);
      expect(appliance['amount'], 300000);
      expect(summary['totalAmount'], 600000);
    });

    test('convierte Aparato 1 a Retenedores al salir de Ortopedia sin perder el total', () async {
      final orthopedicsTreatment = treatment.copyWith(tipoBase: 'ortopedia');
      await db.collection('payments').doc('p1').set({'id': 'p1', 'patientId': 'p1', 'createdAt': DateTime(2026, 4, 1)});
      await db.collection('patients').doc('p1').set({'id': 'p1'});
      await db.collection('patients/p1/treatments').doc('tx-1').set(orthopedicsTreatment.toJson());

      final items = <FinancialItemModel>[
        FinancialItemModel(id: 'initial', patientId: 'p1', treatmentId: 'tx-1', name: 'Inicial', normalizedName: 'inicial', kind: 'initial', amount: 100000, deletable: false, editableName: true, order: 1, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
        FinancialItemModel(id: 'controls', patientId: 'p1', treatmentId: 'tx-1', name: 'Controles', normalizedName: 'controles', kind: 'controls', amount: 200000, deletable: false, editableName: true, order: 2, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
        FinancialItemModel(id: 'appliance_1', patientId: 'p1', treatmentId: 'tx-1', name: 'Aparato 1', normalizedName: 'aparato_1', kind: 'appliance', amount: 300000, deletable: true, editableName: true, order: 3, active: true, createdByAdmin: true, createdAt: DateTime(2026, 4, 1), updatedAt: DateTime(2026, 4, 1)),
      ];
      await repo.replaceFinancialItems(patientId: 'p1', treatment: orthopedicsTreatment, items: items);

      final nonOrthopedics = orthopedicsTreatment.copyWith(tipoBase: 'convencional');
      final converted = await repo.normalizeBaseItemsForTreatmentType(patientId: 'p1', treatment: nonOrthopedics);
      await repo.replaceFinancialItems(patientId: 'p1', treatment: nonOrthopedics, items: converted);

      final snap = await db.collection('patients/p1/treatments/tx-1/financialItems').orderBy('order').get();
      final ids = snap.docs.map((d) => d.id).toList();
      final retainers = snap.docs.firstWhere((d) => d.id == 'retainers').data();
      final summary = (await db.collection('patients/p1/treatments').doc('tx-1').get()).data()?['financialSummary'];

      expect(ids, ['initial', 'controls', 'retainers']);
      expect(ids.contains('appliance_1'), isFalse);
      expect(retainers['amount'], 300000);
      expect(summary['totalAmount'], 600000);
    });
  });
}
