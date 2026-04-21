import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_data_resolution.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/data/services/patient_data_resolution_service.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';

void main() {
  const service = PatientDataResolutionService();

  test('detecta paciente legacy puro', () {
    final patient = _patient();
    final resolved = service.resolve(
      patient: patient,
      newTreatments: const [],
      legacyPayment: _legacyPayment(),
      treatmentPayments: const [],
      legacyTransactions: [_tx('l1', 5, 100000)],
      treatmentTransactions: const [],
    );

    expect(resolved.mode, PatientDataMode.legacyPuro);
    expect(resolved.treatments, hasLength(1));
    expect(resolved.paymentAccounts, hasLength(1));
    expect(resolved.transactions, hasLength(1));
  });

  test('detecta paciente nuevo puro', () {
    final patient = _patient(tipoTratamiento: null);
    final treatment = _newTreatment('t1', isPrimary: true);
    final resolved = service.resolve(
      patient: patient,
      newTreatments: [treatment],
      legacyPayment: null,
      treatmentPayments: [_treatmentPayment('t1')],
      legacyTransactions: const [],
      treatmentTransactions: [_tx('n1', 1, 200000, treatmentId: 't1')],
    );

    expect(resolved.mode, PatientDataMode.nuevoPuro);
    expect(resolved.treatments, hasLength(1));
    expect(resolved.primaryTreatmentId, 't1');
  });

  test('detecta paciente mixto con 1 legacy + 1 nuevo', () {
    final patient = _patient();
    final resolved = service.resolve(
      patient: patient,
      newTreatments: [_newTreatment('t2', tipoBase: 'alineadores')],
      legacyPayment: null,
      treatmentPayments: const [],
      legacyTransactions: const [],
      treatmentTransactions: const [],
    );

    expect(resolved.mode, PatientDataMode.mixto);
    expect(resolved.treatments, hasLength(2));
  });

  test('soporta paciente mixto con pagos legacy + pagos nuevos', () {
    final patient = _patient();
    final resolved = service.resolve(
      patient: patient,
      newTreatments: [_newTreatment('t2')],
      legacyPayment: _legacyPayment(),
      treatmentPayments: [_treatmentPayment('t2')],
      legacyTransactions: const [],
      treatmentTransactions: const [],
    );

    expect(resolved.mode, PatientDataMode.mixto);
    expect(resolved.paymentAccounts.length, greaterThanOrEqualTo(2));
  });

  test('soporta paciente mixto con transacciones legacy + treatment', () {
    final patient = _patient();
    final resolved = service.resolve(
      patient: patient,
      newTreatments: [_newTreatment('t2')],
      legacyPayment: null,
      treatmentPayments: const [],
      legacyTransactions: [_tx('legacy', 5, 100000)],
      treatmentTransactions: [_tx('new', 1, 200000, treatmentId: 't2')],
    );

    expect(resolved.mode, PatientDataMode.mixto);
    expect(resolved.transactions.map((e) => e.id).toList(), ['new', 'legacy']);
  });

  test('paciente con 2 o más tratamientos y uno principal definido', () {
    final patient = _patient(tipoTratamiento: null);
    final resolved = service.resolve(
      patient: patient,
      newTreatments: [
        _newTreatment('t1', isPrimary: true),
        _newTreatment('t2', isPrimary: false),
      ],
      legacyPayment: null,
      treatmentPayments: const [],
      legacyTransactions: const [],
      treatmentTransactions: const [],
    );

    expect(resolved.mode, PatientDataMode.nuevoPuro);
    expect(resolved.treatments, hasLength(2));
    expect(resolved.primaryTreatmentId, 't1');
  });
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
    createdAt: now.subtract(const Duration(days: 100)),
    updatedAt: now,
  );
}

PatientTreatment _newTreatment(
  String id, {
  bool isPrimary = false,
  String tipoBase = 'convencional',
}) {
  final now = DateTime(2026, 4, 21);
  return PatientTreatment(
    id: id,
    patientId: 'p1',
    nombre: 'Tratamiento $id',
    tipoBase: tipoBase,
    categoria: 'Ortodoncia',
    estado: 'activo',
    etapaActual: TreatmentStage.controles,
    fechaInicio: DateTime(2026, 1, 10),
    totalTratamiento: 1000000,
    saldoPendiente: 400000,
    isPrimary: isPrimary,
    createdAt: now.subtract(const Duration(days: 90)),
    updatedAt: now,
    createdBy: 'test',
  );
}

PaymentModel _legacyPayment() {
  final now = DateTime(2026, 4, 21);
  return PaymentModel(
    id: 'p1',
    patientId: 'p1',
    totalTratamiento: 1000000,
    montoPagado: 600000,
    saldoPendiente: 400000,
    fechaProximoPago: now.add(const Duration(days: 10)),
    estado: PaymentStatus.pendiente,
    createdAt: now,
    updatedAt: now,
  );
}

PaymentModel _treatmentPayment(String treatmentId) {
  final now = DateTime(2026, 4, 21);
  return PaymentModel(
    id: treatmentId,
    patientId: 'p1',
    totalTratamiento: 500000,
    montoPagado: 200000,
    saldoPendiente: 300000,
    fechaProximoPago: now.add(const Duration(days: 5)),
    estado: PaymentStatus.pendiente,
    createdAt: now,
    updatedAt: now,
  );
}

PaymentTransaction _tx(
  String id,
  int daysAgo,
  double monto, {
  String? treatmentId,
}) {
  return PaymentTransaction(
    id: id,
    monto: monto,
    fecha: DateTime(2026, 4, 21).subtract(Duration(days: daysAgo)),
    metodo: PaymentMethod.transferencia,
    registradoPor: 'test',
    treatmentId: treatmentId,
  );
}
