import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ocg_proyect/features/auth/providers/auth_providers.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_data_resolution.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/providers/patients_provider.dart';
import 'package:ocg_proyect/features/payments/data/models/financial_item_model.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';
import 'package:ocg_proyect/features/payments/presentation/patient_payments_screen.dart';
import 'package:ocg_proyect/features/payments/providers/payments_provider.dart';
import 'package:ocg_proyect/features/payments/providers/treatment_financial_provider.dart';
import 'package:ocg_proyect/features/payments/services/payu_service.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';

class _RecordingPayuService extends PayuService {
  Map<String, dynamic>? lastCall;

  @override
  Future<String> createPaymentSession({
    required String patientId,
    required String treatmentId,
    required double monto,
    required String patientEmail,
    required String patientName,
    double? saldoPendiente,
  }) async {
    lastCall = {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'monto': monto,
      'patientEmail': patientEmail,
      'patientName': patientName,
      'saldoPendiente': saldoPendiente,
    };
    return 'https://payu.test/checkout';
  }
}

void main() {
  testWidgets('pantalla inicia PayU usando el tratamiento seleccionado', (
    WidgetTester tester,
  ) async {
    final service = _RecordingPayuService();
    await _pumpScreen(
      tester,
      service: service,
      resolution: _resolution(
        patient: _patient(),
        treatments: [_treatment('t1', isPrimary: true), _treatment('t2')],
        accounts: [
          _account('t1', total: 500000, paid: 200000, pending: 300000),
          _account('t2', total: 800000, paid: 100000, pending: 700000),
        ],
      ),
    );

    await tester.tap(find.text('Tratamiento T2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pagar Tratamiento T2 con PayU'));
    await tester.tap(find.text('Pagar Tratamiento T2 con PayU'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(service.lastCall, isNotNull);
    expect(service.lastCall!['treatmentId'], 't2');
    expect(service.lastCall!['monto'], 700000.0);
  });

  testWidgets('cambiar de tratamiento cambia la cuenta y saldo a pagar', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      service: _RecordingPayuService(),
      resolution: _resolution(
        patient: _patient(),
        treatments: [_treatment('t1', isPrimary: true), _treatment('t2')],
        accounts: [
          _account('t1', total: 500000, paid: 200000, pending: 300000),
          _account('t2', total: 800000, paid: 100000, pending: 700000),
        ],
      ),
    );

    expect(find.text('Pagar Tratamiento T1 con PayU'), findsOneWidget);
    await tester.tap(find.text('Tratamiento T2'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar Tratamiento T2 con PayU'), findsOneWidget);
  });

  testWidgets('no existe botón PayU global sin cuenta asociada a tratamiento', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      service: _RecordingPayuService(),
      resolution: _resolution(
        patient: _patient(),
        treatments: [_treatment('t1', isPrimary: true), _treatment('t2')],
        accounts: [
          _account('t1', total: 500000, paid: 200000, pending: 300000),
        ],
      ),
    );

    await tester.tap(find.text('Tratamiento T2'));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'PayU no disponible para Tratamiento T2'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('cuenta de cobro del tratamiento'), findsOneWidget);
    expect(find.textContaining('saldo total del paciente'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _RecordingPayuService service,
  required EffectivePatientDataResolution resolution,
}) async {
  final patient = resolution.patient;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => const Stream<User?>.empty()),
        payuServiceProvider.overrideWith((ref) => service),
        patientByIdProvider(patient.id).overrideWith((ref) => Stream.value(patient)),
        effectivePatientPaymentsProvider((patientId: patient.id, patient: patient))
            .overrideWith((ref) => resolution),
        ensureTreatmentPaymentAccountProvider.overrideWith(
          (ref) => (String patientId, PatientTreatment treatment) async {},
        ),
        for (final treatment in resolution.treatments.where((t) => !t.id.startsWith('legacy-primary-')))
          treatmentFinancialItemsProvider((
            patientId: patient.id,
            treatmentId: treatment.id,
          )).overrideWith((ref) => Stream.value(const <FinancialItemModel>[])),
        for (final treatment in resolution.treatments)
          patientTransactionsProvider((
            patientId: patient.id,
            treatmentId: treatment.id,
          )).overrideWith((ref) => Stream.value(const <PaymentTransaction>[])),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const PatientPaymentsScreen(patientIdOverride: 'p1'),
            ),
            GoRoute(
              path: '/patient/payments/checkout',
              builder: (_, __) => const Scaffold(body: Text('checkout')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EffectivePatientDataResolution _resolution({
  required PatientModel patient,
  required List<PatientTreatment> treatments,
  required List<EffectivePatientPaymentAccount> accounts,
}) {
  return EffectivePatientDataResolution(
    patient: patient,
    mode: PatientDataMode.nuevoPuro,
    treatments: treatments,
    paymentAccounts: accounts,
    transactions: const <PaymentTransaction>[],
    hasLegacyTreatmentProjection: false,
    hasNewTreatments: true,
    hasLegacyPaymentAccount: false,
    hasNewPaymentAccounts: true,
    hasLegacyTransactions: false,
    hasNewTransactions: false,
    primaryTreatmentId: treatments.first.id,
  );
}

EffectivePatientPaymentAccount _account(
  String treatmentId, {
  required double total,
  required double paid,
  required double pending,
}) {
  return EffectivePatientPaymentAccount(
    payment: PaymentModel(
      id: treatmentId,
      patientId: 'p1',
      totalTratamiento: total,
      montoPagado: paid,
      saldoPendiente: pending,
      fechaProximoPago: null,
      estado: PaymentStatus.pendiente,
      createdAt: DateTime(2026, 5, 4),
      updatedAt: DateTime(2026, 5, 4),
    ),
    treatmentId: treatmentId,
    isLegacy: false,
    source: 'treatment-payment',
  );
}

PatientModel _patient() {
  final now = DateTime(2026, 5, 4);
  return PatientModel(
    id: 'p1',
    nombre: 'Paciente Demo',
    email: 'demo@example.com',
    telefono: '3000000000',
    fechaNacimiento: DateTime(1990, 1, 1),
    tipoTratamiento: null,
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
  final now = DateTime(2026, 5, 4);
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
  );
}
