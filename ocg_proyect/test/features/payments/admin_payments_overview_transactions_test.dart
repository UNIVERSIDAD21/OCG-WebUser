import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/payments/data/models/admin_payment_overview.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';
import 'package:ocg_proyect/features/payments/data/repositories/payments_repository.dart';

void main() {
  group('mergePatientTransactionsForOverview', () {
    test('soporta paciente con pagos legacy solamente', () {
      final legacy = [_tx(id: 'l1', daysAgo: 5, amount: 100000)];
      final merged = mergePatientTransactionsForOverview(legacy, const []);
      expect(merged, hasLength(1));
      expect(merged.first.id, 'l1');
    });

    test('soporta paciente con pagos por tratamiento solamente', () {
      final treatment = [
        _tx(id: 't1', daysAgo: 1, amount: 200000, treatmentId: 'tr1'),
      ];
      final merged = mergePatientTransactionsForOverview(const [], treatment);
      expect(merged, hasLength(1));
      expect(merged.first.treatmentId, 'tr1');
    });

    test('deduplica paciente mixto legacy + treatment', () {
      final duplicate = _tx(
        id: 'same',
        daysAgo: 2,
        amount: 150000,
        treatmentId: 'tr1',
      );
      final merged = mergePatientTransactionsForOverview(
        [_tx(id: 'legacy-only', daysAgo: 4, amount: 90000), duplicate],
        [duplicate, _tx(id: 'new-only', daysAgo: 1, amount: 300000)],
      );
      expect(merged, hasLength(3));
      expect(merged.where((tx) => tx.id == 'same'), hasLength(1));
    });

    test('paciente sin pagos devuelve vacío', () {
      final merged = mergePatientTransactionsForOverview(const [], const []);
      expect(merged, isEmpty);
    });

    test('ordena múltiples transacciones por fecha descendente', () {
      final merged = mergePatientTransactionsForOverview(
        [
          _tx(id: 'a', daysAgo: 10, amount: 50000),
          _tx(id: 'b', daysAgo: 3, amount: 60000),
        ],
        [_tx(id: 'c', daysAgo: 1, amount: 70000, treatmentId: 'tr1')],
      );
      expect(merged.map((e) => e.id).toList(), ['c', 'b', 'a']);
    });
  });

  group('AdminPaymentsOverview', () {
    test('llena latest payment, método y fecha correcta en overview admin', () {
      final patient = _patient();
      final payment = _payment();
      final latest = _tx(
        id: 'latest',
        daysAgo: 1,
        amount: 250000,
        method: PaymentMethod.transferencia,
      );
      final older = _tx(
        id: 'older',
        daysAgo: 4,
        amount: 100000,
        method: PaymentMethod.efectivo,
      );

      final entry = AdminPaymentEntry(
        patient: patient,
        payment: payment,
        latestTransaction: latest,
      );
      final overview = AdminPaymentsOverview(
        entries: [entry],
        totalDebt: payment.saldoPendiente,
        transactionsThisMonth: 2,
        history: [
          AdminPaymentHistoryItem(
            patient: patient,
            payment: payment,
            transaction: latest,
          ),
          AdminPaymentHistoryItem(
            patient: patient,
            payment: payment,
            transaction: older,
          ),
        ],
      );

      expect(overview.recentIncomeEntries, hasLength(1));
      expect(overview.recentIncomeEntries.first.latestPaymentAmount, 250000);
      expect(
        overview.recentIncomeEntries.first.latestPaymentMethodLabel,
        'Transferencia',
      );
      expect(overview.history.first.transaction.id, 'latest');
      expect(overview.history.first.paymentMethodLabel, 'Transferencia');
      expect(overview.history.last.transaction.id, 'older');
    });
  });
}

PatientModel _patient() {
  final now = DateTime(2026, 4, 21);
  return PatientModel(
    id: 'p1',
    nombre: 'Paciente Demo',
    email: 'demo@example.com',
    telefono: '3000000000',
    fechaNacimiento: DateTime(1990, 1, 1),
    tipoTratamiento: TreatmentType.convencional,
    etapaActual: TreatmentStage.controles,
    fechaInicio: now.subtract(const Duration(days: 100)),
    notasClinicas: 'demo',
    totalTratamiento: 1000000,
    saldoPendiente: 400000,
    createdAt: now.subtract(const Duration(days: 120)),
    updatedAt: now,
  );
}

PaymentModel _payment() {
  final now = DateTime(2026, 4, 21);
  return PaymentModel(
    id: 'p1',
    patientId: 'p1',
    totalTratamiento: 1000000,
    montoPagado: 600000,
    saldoPendiente: 400000,
    fechaProximoPago: now.add(const Duration(days: 10)),
    estado: PaymentStatus.pendiente,
    createdAt: now.subtract(const Duration(days: 120)),
    updatedAt: now,
  );
}

PaymentTransaction _tx({
  required String id,
  required int daysAgo,
  required double amount,
  PaymentMethod method = PaymentMethod.efectivo,
  String? treatmentId,
}) {
  return PaymentTransaction(
    id: id,
    monto: amount,
    fecha: DateTime(2026, 4, 21).subtract(Duration(days: daysAgo)),
    metodo: method,
    registradoPor: 'admin',
    treatmentId: treatmentId,
  );
}
