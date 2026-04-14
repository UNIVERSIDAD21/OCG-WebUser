import 'package:flutter_test/flutter_test.dart';

import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/payments/data/models/admin_payment_overview.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';

PatientModel _patient(String id, String name) {
  return PatientModel(
    id: id,
    nombre: name,
    email: '$id@ocg.com',
    telefono: '3000000000',
    fechaNacimiento: DateTime(2000, 1, 1),
    tipoTratamiento: TreatmentType.convencional,
    etapaActual: TreatmentStage.controles,
    fechaInicio: DateTime(2026, 1, 1),
    notasClinicas: '',
    totalTratamiento: 9000000,
    saldoPendiente: 0,
  );
}

PaymentModel _payment({
  required String id,
  required double montoPagado,
  required double saldoPendiente,
  DateTime? fechaProximoPago,
}) {
  final now = DateTime(2026, 4, 14);
  return PaymentModel(
    id: id,
    patientId: id,
    totalTratamiento: 9000000,
    montoPagado: montoPagado,
    saldoPendiente: saldoPendiente,
    fechaProximoPago: fechaProximoPago,
    estado: PaymentModel.calcularEstado(
      saldoPendiente: saldoPendiente,
      fechaProximoPago: fechaProximoPago,
      now: now,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

PaymentTransaction _transaction({
  required String id,
  required double monto,
  required DateTime fecha,
  PaymentMethod metodo = PaymentMethod.transferencia,
}) {
  return PaymentTransaction(
    id: id,
    monto: monto,
    fecha: fecha,
    metodo: metodo,
    registradoPor: 'admin',
  );
}

void main() {
  group('AdminPaymentEntry', () {
    test('clasifica filtros financieros correctamente', () {
      final paid = AdminPaymentEntry(
        patient: _patient('p1', 'Pagado'),
        payment: _payment(id: 'p1', montoPagado: 9000000, saldoPendiente: 0),
        latestTransaction: _transaction(
          id: 't1',
          monto: 500000,
          fecha: DateTime(2026, 4, 10),
        ),
      );
      final overdue = AdminPaymentEntry(
        patient: _patient('p2', 'Vencido'),
        payment: _payment(
          id: 'p2',
          montoPagado: 1000000,
          saldoPendiente: 8000000,
          fechaProximoPago: DateTime(2026, 4, 10),
        ),
        latestTransaction: _transaction(
          id: 't2',
          monto: 1000000,
          fecha: DateTime(2026, 4, 9),
        ),
      );
      final pending = AdminPaymentEntry(
        patient: _patient('p3', 'Pendiente'),
        payment: _payment(
          id: 'p3',
          montoPagado: 2000000,
          saldoPendiente: 7000000,
          fechaProximoPago: DateTime.now().add(const Duration(days: 20)),
        ),
      );

      expect(paid.matchesFilter(AdminPaymentsFilter.pagado), isTrue);
      expect(overdue.matchesFilter(AdminPaymentsFilter.vencido), isTrue);
      expect(pending.matchesFilter(AdminPaymentsFilter.pendiente), isTrue);
      expect(overdue.financialStatusLabel, 'Vencido');
      expect(paid.latestPaymentMethodLabel, 'Transferencia');
      expect(pending.latestPaymentMethodLabel, 'Sin pagos');
    });
  });

  group('AdminPaymentsOverview', () {
    test('ordena ingresos recientes por fecha del último pago', () {
      final older = AdminPaymentEntry(
        patient: _patient('p1', 'Ana'),
        payment: _payment(
          id: 'p1',
          montoPagado: 1000000,
          saldoPendiente: 8000000,
        ),
        latestTransaction: _transaction(
          id: 't1',
          monto: 500000,
          fecha: DateTime(2026, 4, 1),
        ),
      );
      final newer = AdminPaymentEntry(
        patient: _patient('p2', 'Beto'),
        payment: _payment(
          id: 'p2',
          montoPagado: 2000000,
          saldoPendiente: 7000000,
        ),
        latestTransaction: _transaction(
          id: 't2',
          monto: 750000,
          fecha: DateTime(2026, 4, 12),
          metodo: PaymentMethod.payu,
        ),
      );
      final noPayments = AdminPaymentEntry(
        patient: _patient('p3', 'Carla'),
        payment: _payment(id: 'p3', montoPagado: 0, saldoPendiente: 9000000),
      );

      final overview = AdminPaymentsOverview(
        entries: [older, newer, noPayments],
        totalDebt: 24000000,
        transactionsThisMonth: 2,
      );

      expect(overview.recentIncomeEntries.map((e) => e.patient.id), [
        'p2',
        'p1',
      ]);
      expect(overview.entriesForFilter(AdminPaymentsFilter.pagado), isEmpty);
      expect(overview.entriesForFilter(AdminPaymentsFilter.todos).length, 3);
    });
  });
}
