import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';
import 'package:ocg_proyect/features/payments/data/repositories/payments_repository.dart';
import 'package:ocg_proyect/shared/constants/firestore_paths.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PaymentsRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PaymentsRepository(db);
  });

  Future<void> seedPatientAndPayment({
    required String patientId,
    double total = 1000,
    double paid = 200,
    double saldo = 800,
  }) async {
    await db.collection(FirestorePaths.patients).doc(patientId).set({
      'id': patientId,
      'saldoPendiente': saldo,
    });
    await db.collection(FirestorePaths.payments).doc(patientId).set({
      'id': patientId,
      'patientId': patientId,
      'totalTratamiento': total,
      'montoPagado': paid,
      'saldoPendiente': saldo,
      'fechaProximoPago': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'estado': PaymentStatus.alDia.name,
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });
  }

  Future<void> seedTreatmentAccount({
    required String patientId,
    required String treatmentId,
    required bool isPrimary,
    double total = 1000,
    double paid = 200,
    double saldo = 800,
    String name = 'Tratamiento',
  }) async {
    await db.collection(FirestorePaths.patients).doc(patientId).set({
      'id': patientId,
      'primaryTreatmentId': isPrimary ? treatmentId : null,
      'saldoPendiente': saldo,
    }, SetOptions(merge: true));
    await db.collection(FirestorePaths.patientTreatments(patientId)).doc(treatmentId).set({
      'id': treatmentId,
      'patientId': patientId,
      'nombre': name,
      'categoria': 'ortodoncia',
      'tipoBase': 'convencional',
      'estado': 'activo',
      'etapaActual': 'valoracionInicial',
      'fechaInicio': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'createdAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'isPrimary': isPrimary,
      'totalTratamiento': total,
      'saldoPendiente': saldo,
    });
    await db.collection(FirestorePaths.treatmentPayments(patientId)).doc(treatmentId).set({
      'id': treatmentId,
      'patientId': patientId,
      'treatmentId': treatmentId,
      'totalTratamiento': total,
      'montoPagado': paid,
      'saldoPendiente': saldo,
      'fechaProximoPago': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'estado': PaymentStatus.alDia.name,
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });
  }

  group('watchers', () {
    test('watchPatientPayments usa acceso directo por patientId', () async {
      await seedPatientAndPayment(patientId: 'p1');

      final payment = await repo.watchPatientPayments('p1').first;
      expect(payment, isNotNull);
      expect(payment!.id, 'p1');
      expect(payment.patientId, 'p1');
    });

    test('watchTransactions ordena por fecha desc', () async {
      await db.collection(FirestorePaths.transactions('p1')).add({
        'id': 'a',
        'monto': 100,
        'fecha': Timestamp.fromDate(DateTime(2026, 3, 10)),
        'metodo': PaymentMethod.efectivo.name,
        'registradoPor': 'admin',
      });
      await db.collection(FirestorePaths.transactions('p1')).add({
        'id': 'b',
        'monto': 200,
        'fecha': Timestamp.fromDate(DateTime(2026, 3, 11)),
        'metodo': PaymentMethod.transferencia.name,
        'registradoPor': 'admin',
      });

      final txs = await repo.watchTransactions('p1').first;
      expect(txs.length, 2);
      expect(txs.first.monto, 200);
    });
  });

  group('initializePaymentDocument', () {
    test('crea documento si no existe', () async {
      await repo.initializePaymentDocument(
        patientId: 'p-init',
        totalTratamiento: 1500,
      );
      final doc = await db
          .collection(FirestorePaths.payments)
          .doc('p-init')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['patientId'], 'p-init');
      expect(doc.data()!['saldoPendiente'], 1500);
    });

    test('es idempotente si ya existe', () async {
      await db.collection(FirestorePaths.payments).doc('p-init').set({
        'id': 'p-init',
        'patientId': 'p-init',
        'saldoPendiente': 99,
      });
      await repo.initializePaymentDocument(
        patientId: 'p-init',
        totalTratamiento: 1500,
      );
      final doc = await db
          .collection(FirestorePaths.payments)
          .doc('p-init')
          .get();
      expect(doc.data()!['saldoPendiente'], 99);
    });
  });

  group('registerManualPayment', () {
    test('valida monto > 0', () async {
      await seedTreatmentAccount(
        patientId: 'p2',
        treatmentId: 'tx-1',
        isPrimary: true,
      );
      await expectLater(
        () => repo.registerManualPayment(
          patientId: 'p2',
          treatmentId: 'tx-1',
          monto: 0,
          metodo: PaymentMethod.efectivo,
          adminId: 'admin1',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valida monto no supere saldo', () async {
      await seedTreatmentAccount(
        patientId: 'p2',
        treatmentId: 'tx-1',
        isPrimary: true,
        saldo: 50,
      );
      await expectLater(
        () => repo.registerManualPayment(
          patientId: 'p2',
          treatmentId: 'tx-1',
          monto: 100,
          metodo: PaymentMethod.efectivo,
          adminId: 'admin1',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rechaza pago manual sin treatmentId', () async {
      await seedPatientAndPayment(patientId: 'p2', paid: 200, saldo: 800);

      await expectLater(
        () => repo.registerManualPayment(
          patientId: 'p2',
          monto: 300,
          metodo: PaymentMethod.transferencia,
          adminId: 'admin-1',
          referencia: 'TRF-123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('batch actualiza cuenta/tratamiento primario y espejo legacy', () async {
      await seedTreatmentAccount(
        patientId: 'p2',
        treatmentId: 'tx-1',
        isPrimary: true,
        total: 1000,
        paid: 200,
        saldo: 800,
      );

      await repo.registerManualPayment(
        patientId: 'p2',
        treatmentId: 'tx-1',
        monto: 300,
        metodo: PaymentMethod.transferencia,
        adminId: 'admin-1',
        referencia: 'TRF-123',
      );

      final payDoc = await db.doc(FirestorePaths.treatmentPaymentDoc('p2', 'tx-1')).get();
      final legacyDoc = await db.collection(FirestorePaths.payments).doc('p2').get();
      final patientDoc = await db.collection(FirestorePaths.patients).doc('p2').get();
      final txSnap = await db.collection(FirestorePaths.treatmentTransactions('p2', 'tx-1')).get();

      expect(payDoc.data()!['montoPagado'], 500);
      expect(payDoc.data()!['saldoPendiente'], 500);
      expect(legacyDoc.data()!['saldoPendiente'], 500);
      final patientOverview = (patientDoc.data()!['treatmentOverview'] as Map<String, dynamic>?) ?? const {};
      final patientFinancial = (patientOverview['financial'] as Map<String, dynamic>?) ?? const {};
      expect(patientFinancial['saldoPendiente'], 500);
      expect(txSnap.docs.length, 1);
      expect(txSnap.docs.first.data()['registradoPor'], 'admin-1');
    });

    test(
      'si recibe treatmentId actualiza saldo del tratamiento y marca la transacción',
      () async {
        await seedTreatmentAccount(
          patientId: 'p2',
          treatmentId: 'tx-1',
          isPrimary: true,
          total: 1800,
          paid: 300,
          saldo: 1500,
        );

        await repo.registerManualPayment(
          patientId: 'p2',
          treatmentId: 'tx-1',
          monto: 200,
          metodo: PaymentMethod.efectivo,
          adminId: 'admin-1',
        );

        final treatmentDoc = await db
            .collection(FirestorePaths.patientTreatments('p2'))
            .doc('tx-1')
            .get();
        final txSnap = await db
            .collection(FirestorePaths.treatmentTransactions('p2', 'tx-1'))
            .get();
        expect(treatmentDoc.data()!['saldoPendiente'], 1300);
        expect(txSnap.docs.first.data()['treatmentId'], 'tx-1');
      },
    );
  });

  group('registerGatewayPayment', () {
    test('registra tx con metadata epayco y epayco_webhook', () async {
      await seedTreatmentAccount(
        patientId: 'p3',
        treatmentId: 'tx-main',
        isPrimary: true,
        paid: 0,
        saldo: 1000,
      );

      await repo.registerGatewayPayment(
        patientId: 'p3',
        treatmentId: 'tx-main',
        monto: 400,
        epaycoOrderId: 'ORDER1',
        epaycoTransactionId: 'TX1',
      );

      final txSnap = await db
          .collection(FirestorePaths.treatmentTransactions('p3', 'tx-main'))
          .get();
      expect(txSnap.docs.length, 1);
      final tx = txSnap.docs.first.data();
      expect(tx['registradoPor'], 'epayco_webhook');
      expect(tx['metodo'], PaymentMethod.epayco.name);
      expect(tx['epaycoOrderId'], 'ORDER1');
      expect(tx['epaycoTransactionId'], 'TX1');
      expect(tx['treatmentId'], 'tx-main');
    });

    test('aplica pago Epayco a tratamiento A sin afectar tratamiento B', () async {
      await seedTreatmentAccount(
        patientId: 'p-multi',
        treatmentId: 'tx-a',
        isPrimary: true,
        total: 1200,
        paid: 200,
        saldo: 1000,
        name: 'Tratamiento A',
      );
      await seedTreatmentAccount(
        patientId: 'p-multi',
        treatmentId: 'tx-b',
        isPrimary: false,
        total: 900,
        paid: 100,
        saldo: 800,
        name: 'Tratamiento B',
      );

      await repo.registerGatewayPayment(
        patientId: 'p-multi',
        treatmentId: 'tx-a',
        monto: 300,
        epaycoOrderId: 'ORDER-A',
        epaycoTransactionId: 'TX-A',
      );

      final paymentA = await db.doc(FirestorePaths.treatmentPaymentDoc('p-multi', 'tx-a')).get();
      final paymentB = await db.doc(FirestorePaths.treatmentPaymentDoc('p-multi', 'tx-b')).get();
      final txA = await db.collection(FirestorePaths.treatmentTransactions('p-multi', 'tx-a')).get();
      final txB = await db.collection(FirestorePaths.treatmentTransactions('p-multi', 'tx-b')).get();

      expect(paymentA.data()!['saldoPendiente'], 700);
      expect(paymentB.data()!['saldoPendiente'], 800);
      expect(txA.docs, hasLength(1));
      expect(txB.docs, isEmpty);
    });
  });

  group('update methods', () {
    test('updateTransactionReceiptUrl actualiza reciboUrl', () async {
      final txRef = db.collection(FirestorePaths.transactions('p4')).doc('tx1');
      await txRef.set({
        'id': 'tx1',
        'monto': 100,
        'fecha': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'metodo': PaymentMethod.efectivo.name,
        'registradoPor': 'admin',
      });

      await repo.updateTransactionReceiptUrl(
        patientId: 'p4',
        transactionId: 'tx1',
        reciboUrl: 'https://x/recibo.pdf',
      );

      final tx = await txRef.get();
      expect(tx.data()!['reciboUrl'], 'https://x/recibo.pdf');
    });

    test('updateNextPaymentDate recalcula estado', () async {
      await seedPatientAndPayment(patientId: 'p5', saldo: 100);
      await repo.updateNextPaymentDate(
        'p5',
        DateTime.now().subtract(const Duration(days: 1)),
      );

      final pay = await db.collection(FirestorePaths.payments).doc('p5').get();
      expect(pay.data()!['estado'], PaymentStatus.vencido.name);
      expect(pay.data()!['fechaProximoPago'], isA<Timestamp>());
    });
  });
}
