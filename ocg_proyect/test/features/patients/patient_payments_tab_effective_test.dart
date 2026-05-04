import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_data_resolution.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/presentation/tabs/patient_payments_tab.dart';
import 'package:ocg_proyect/features/patients/providers/patients_provider.dart';
import 'package:ocg_proyect/features/payments/data/models/financial_item_model.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';
import 'package:ocg_proyect/features/payments/providers/payments_provider.dart';
import 'package:ocg_proyect/features/payments/providers/treatment_financial_provider.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';

void main() {
  testWidgets(
    'paciente sin pagos muestra vacío limpio y no permission-denied',
    (WidgetTester tester) async {
      final patient = _patient();
      final treatment = _treatment('t1', isPrimary: true);
      final resolution = _resolution(
        patient: patient,
        treatments: [treatment],
        accounts: const [],
        transactions: const [],
        mode: PatientDataMode.nuevoPuro,
      );

      await _pump(
        tester,
        patient: patient,
        resolution: resolution,
        transactionsByScope: const {
          'global': <PaymentTransaction>[],
          't1': <PaymentTransaction>[],
        },
      );

      expect(find.text('No hay cuentas de pago todavía.'), findsOneWidget);
      expect(find.textContaining('permissions'), findsNothing);
    },
  );

  testWidgets('paciente con pagos legacy muestra cuenta visible', (
    WidgetTester tester,
  ) async {
    final patient = _patient();
    final treatment = _treatment('legacy-primary-p1', isPrimary: true);
    final legacyPayment = _payment(
      'p1',
      total: 1000000,
      paid: 400000,
      pending: 600000,
    );
    final resolution = _resolution(
      patient: patient,
      treatments: [treatment],
      accounts: [
        EffectivePatientPaymentAccount(
          payment: legacyPayment,
          treatmentId: null,
          isLegacy: true,
          source: 'legacy-payment',
        ),
      ],
      transactions: [_tx('legacy', 5, 100000)],
      mode: PatientDataMode.legacyPuro,
    );

    await _pump(
      tester,
      patient: patient,
      resolution: resolution,
      transactionsByScope: {
        'global': [_tx('legacy', 5, 100000)],
        'legacy-primary-p1': const <PaymentTransaction>[],
      },
    );

    expect(find.text('Cuenta legacy'), findsOneWidget);
    expect(find.textContaining('600.000'), findsWidgets);
  });

  testWidgets(
    'paciente con pagos por tratamiento muestra múltiples cuentas activas',
    (WidgetTester tester) async {
      final patient = _patient(tipoTratamiento: null);
      final t1 = _treatment('t1', isPrimary: true);
      final t2 = _treatment('t2');
      final resolution = _resolution(
        patient: patient,
        treatments: [t1, t2],
        accounts: [
          EffectivePatientPaymentAccount(
            payment: _payment(
              't1',
              total: 500000,
              paid: 200000,
              pending: 300000,
            ),
            treatmentId: 't1',
            isLegacy: false,
            source: 'treatment-payment',
          ),
          EffectivePatientPaymentAccount(
            payment: _payment(
              't2',
              total: 800000,
              paid: 100000,
              pending: 700000,
            ),
            treatmentId: 't2',
            isLegacy: false,
            source: 'treatment-payment',
          ),
        ],
        transactions: [
          _tx('a', 3, 100000, treatmentId: 't1'),
          _tx('b', 1, 50000, treatmentId: 't2'),
        ],
        mode: PatientDataMode.nuevoPuro,
      );

      await _pump(
        tester,
        patient: patient,
        resolution: resolution,
        transactionsByScope: {
          'global': [
            _tx('a', 3, 100000, treatmentId: 't1'),
            _tx('b', 1, 50000, treatmentId: 't2'),
          ],
          't1': [_tx('a', 3, 100000, treatmentId: 't1')],
          't2': [_tx('b', 1, 50000, treatmentId: 't2')],
        },
      );

      expect(find.text('Tratamiento T1'), findsWidgets);
      expect(find.text('Tratamiento T2'), findsWidgets);
    },
  );

  testWidgets(
    'paciente mixto soporta historial global y filtrado por tratamiento',
    (WidgetTester tester) async {
      final patient = _patient();
      final t1 = _treatment('legacy-primary-p1', isPrimary: true);
      final t2 = _treatment('t2');
      final globalTx = [
        _tx('legacy', 6, 100000),
        _tx('new', 1, 300000, treatmentId: 't2'),
      ];
      final resolution = _resolution(
        patient: patient,
        treatments: [t1, t2],
        accounts: [
          EffectivePatientPaymentAccount(
            payment: _payment(
              'p1',
              total: 1000000,
              paid: 400000,
              pending: 600000,
            ),
            treatmentId: null,
            isLegacy: true,
            source: 'legacy-payment',
          ),
          EffectivePatientPaymentAccount(
            payment: _payment(
              't2',
              total: 900000,
              paid: 300000,
              pending: 600000,
            ),
            treatmentId: 't2',
            isLegacy: false,
            source: 'treatment-payment',
          ),
        ],
        transactions: globalTx,
        mode: PatientDataMode.mixto,
      );

      await _pump(
        tester,
        patient: patient,
        resolution: resolution,
        transactionsByScope: {
          'global': globalTx,
          'legacy-primary-p1': const <PaymentTransaction>[],
          't2': [_tx('new', 1, 300000, treatmentId: 't2')],
        },
      );

      expect(find.text('Pagos del paciente'), findsOneWidget);
      await tester.tap(find.text('Tratamiento T2').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Historial de Tratamiento T2'), findsOneWidget);
    },
  );

  testWidgets('registrar pago exige cuenta específica correcta', (
    WidgetTester tester,
  ) async {
    final patient = _patient(tipoTratamiento: null);
    final t1 = _treatment('t1', isPrimary: true);
    final resolution = _resolution(
      patient: patient,
      treatments: [t1],
      accounts: [
        EffectivePatientPaymentAccount(
          payment: _payment('t1', total: 500000, paid: 200000, pending: 300000),
          treatmentId: 't1',
          isLegacy: false,
          source: 'treatment-payment',
        ),
      ],
      transactions: const [],
      mode: PatientDataMode.nuevoPuro,
    );

    await _pump(
      tester,
      patient: patient,
      resolution: resolution,
      transactionsByScope: const {
        'global': <PaymentTransaction>[],
        't1': <PaymentTransaction>[],
      },
    );

    final registerCta = find.textContaining('Registrar pago en');
    expect(registerCta, findsWidgets);
    await tester.ensureVisible(registerCta.first);
    await tester.tap(registerCta.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Registrar pago'), findsWidgets);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required PatientModel patient,
  required EffectivePatientDataResolution resolution,
  required Map<String, List<PaymentTransaction>> transactionsByScope,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientByIdProvider(
          patient.id,
        ).overrideWith((ref) => Stream.value(patient)),
        effectivePatientPaymentsProvider((
          patientId: patient.id,
          patient: patient,
        )).overrideWith((ref) => resolution),
        ensureTreatmentPaymentAccountProvider.overrideWith(
          (ref) => (String patientId, PatientTreatment treatment) async {},
        ),
        ensureTreatmentFinancialItemsProvider.overrideWith(
          (ref) => (String patientId, PatientTreatment treatment) async {},
        ),
        for (final treatment in resolution.treatments.where(
          (t) => !t.id.startsWith('legacy-primary-'),
        ))
          treatmentFinancialItemsProvider((
            patientId: patient.id,
            treatmentId: treatment.id,
          )).overrideWith((ref) => Stream.value(const <FinancialItemModel>[])),
        for (final entry in transactionsByScope.entries)
          patientTransactionsProvider((
            patientId: patient.id,
            treatmentId: entry.key == 'global' ? null : entry.key,
          )).overrideWith((ref) => Stream.value(entry.value)),
      ],
      child: MaterialApp(
        home: Scaffold(body: PatientPaymentsTab(patientId: patient.id)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EffectivePatientDataResolution _resolution({
  required PatientModel patient,
  required List<PatientTreatment> treatments,
  required List<EffectivePatientPaymentAccount> accounts,
  required List<PaymentTransaction> transactions,
  required PatientDataMode mode,
}) {
  return EffectivePatientDataResolution(
    patient: patient,
    mode: mode,
    treatments: treatments,
    paymentAccounts: accounts,
    transactions: transactions,
    hasLegacyTreatmentProjection: mode != PatientDataMode.nuevoPuro,
    hasNewTreatments: treatments.any(
      (t) => !t.id.startsWith('legacy-primary-'),
    ),
    hasLegacyPaymentAccount: accounts.any((a) => a.isLegacy),
    hasNewPaymentAccounts: accounts.any((a) => !a.isLegacy),
    hasLegacyTransactions: transactions.any((t) => t.treatmentId == null),
    hasNewTransactions: transactions.any((t) => t.treatmentId != null),
    primaryTreatmentId: treatments.isEmpty ? null : treatments.first.id,
  );
}

PatientModel _patient({
  TreatmentType? tipoTratamiento = TreatmentType.convencional,
}) {
  final now = DateTime(2026, 4, 21);
  return PatientModel(
    id: 'p1',
    nombre: 'Paciente Demo',
    email: 'demo@example.com',
    telefono: '3000000000',
    fechaNacimiento: DateTime(1990, 1, 1),
    tipoTratamiento: tipoTratamiento,
    etapaActual: TreatmentStage.controles,
    fechaInicio: DateTime(2026, 1, 10),
    notasClinicas: 'demo',
    totalTratamiento: 1000000,
    saldoPendiente: 400000,
    createdAt: now,
    updatedAt: now,
  );
}

PatientTreatment _treatment(String id, {bool isPrimary = false}) {
  final now = DateTime(2026, 4, 21);
  return PatientTreatment(
    id: id,
    patientId: 'p1',
    nombre: 'Tratamiento $id',
    tipoBase: 'convencional',
    categoria: 'Ortodoncia',
    estado: 'activo',
    etapaActual: TreatmentStage.controles,
    fechaInicio: DateTime(2026, 1, 10),
    totalTratamiento: 500000,
    saldoPendiente: 300000,
    isPrimary: isPrimary,
    createdAt: now,
    updatedAt: now,
    createdBy: 'test',
  );
}

PaymentModel _payment(
  String id, {
  required double total,
  required double paid,
  required double pending,
}) {
  final now = DateTime(2026, 4, 21);
  return PaymentModel(
    id: id,
    patientId: 'p1',
    totalTratamiento: total,
    montoPagado: paid,
    saldoPendiente: pending,
    fechaProximoPago: now.add(const Duration(days: 10)),
    estado: PaymentStatus.pendiente,
    createdAt: now,
    updatedAt: now,
  );
}

PaymentTransaction _tx(
  String id,
  int daysAgo,
  double amount, {
  String? treatmentId,
}) {
  return PaymentTransaction(
    id: id,
    monto: amount,
    fecha: DateTime(2026, 4, 21).subtract(Duration(days: daysAgo)),
    metodo: PaymentMethod.transferencia,
    registradoPor: 'admin',
    treatmentId: treatmentId,
  );
}
