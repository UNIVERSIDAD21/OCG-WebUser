import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/models/financial_item_model.dart';
import 'package:ocg_proyect/features/payments/providers/treatment_financial_provider.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/presentation/tabs/patient_treatment_tab.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';
import 'package:ocg_proyect/features/treatment/data/models/stage_history_entry.dart';
import 'package:ocg_proyect/features/treatment/providers/patient_treatments_provider.dart';
import 'package:ocg_proyect/features/treatment/providers/treatment_provider.dart';

void main() {
  testWidgets('paciente con 1 tratamiento muestra un único tratamiento', (
    WidgetTester tester,
  ) async {
    final patient = _patient();
    final treatment = _treatment('t1', isPrimary: true);

    await _pumpTreatmentTab(
      tester,
      patient: patient,
      treatments: [treatment],
      financialItemsByTreatment: {
        't1': [_item('i1', 'Cuota inicial', 500000, 't1')],
      },
      historyByTreatment: {
        't1': [_history('h1', 't1', TreatmentStage.controles)],
      },
    );

    expect(find.text('Tratamientos del paciente'), findsOneWidget);
    expect(find.byKey(const ValueKey('treatment-stream-t1')), findsOneWidget);
    expect(find.text('1 tratamiento'), findsOneWidget);
  });

  testWidgets('paciente con 2 tratamientos nuevos muestra ambos en selector', (
    WidgetTester tester,
  ) async {
    final patient = _patient(tipoTratamiento: null);
    final t1 = _treatment('t1', isPrimary: true);
    final t2 = _treatment('t2', tipoBase: 'alineadores');

    await _pumpTreatmentTab(
      tester,
      patient: patient,
      treatments: [t1, t2],
      financialItemsByTreatment: {
        't1': [_item('i1', 'Cuota inicial', 500000, 't1')],
        't2': [_item('i2', 'Alineadores', 900000, 't2')],
      },
      historyByTreatment: {
        't1': [_history('h1', 't1', TreatmentStage.controles)],
        't2': [_history('h2', 't2', TreatmentStage.retencion)],
      },
    );

    expect(find.byKey(const ValueKey('treatment-stream-t1')), findsOneWidget);
    expect(find.byKey(const ValueKey('treatment-stream-t2')), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('paciente mixto legacy + nuevo no oculta tratamientos reales', (
    WidgetTester tester,
  ) async {
    final patient = _patient();
    final t2 = _treatment('t2', tipoBase: 'alineadores');

    await _pumpTreatmentTab(
      tester,
      patient: patient,
      treatments: [t2],
      financialItemsByTreatment: {
        't2': [_item('i2', 'Alineadores', 900000, 't2')],
      },
      historyByTreatment: {
        't2': [_history('h2', 't2', TreatmentStage.retencion)],
      },
      legacyHistory: [
        _history('legacy', 'legacy-primary-p1', TreatmentStage.controles),
      ],
    );

    expect(
      find.textContaining('Paciente en transición legacy + nuevo'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('treatment-stream-t2')), findsOneWidget);
    expect(find.textContaining('Tratamiento principal'), findsOneWidget);
  });

  testWidgets(
    'paciente con 3 tratamientos destaca principal sin ocultar secundarios',
    (WidgetTester tester) async {
      final patient = _patient(tipoTratamiento: null);
      final treatments = [
        _treatment('t1', isPrimary: true),
        _treatment('t2', tipoBase: 'alineadores'),
        _treatment('t3', tipoBase: 'cirugia'),
      ];

      await _pumpTreatmentTab(
        tester,
        patient: patient,
        treatments: treatments,
        financialItemsByTreatment: {
          for (final treatment in treatments)
            treatment.id: [
              _item(
                'i-${treatment.id}',
                'Concepto ${treatment.id}',
                100000,
                treatment.id,
              ),
            ],
        },
        historyByTreatment: {
          for (final treatment in treatments)
            treatment.id: [
              _history(
                'h-${treatment.id}',
                treatment.id,
                TreatmentStage.controles,
              ),
            ],
        },
      );

      expect(find.byKey(const ValueKey('treatment-stream-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('treatment-stream-t2')), findsOneWidget);
      expect(find.byKey(const ValueKey('treatment-stream-t3')), findsOneWidget);
      expect(find.text('Tratamientos secundarios visibles'), findsOneWidget);
    },
  );

  testWidgets(
    'cambio de selección actualiza hero, resumen e historial del tratamiento visible',
    (WidgetTester tester) async {
      final patient = _patient(tipoTratamiento: null);
      final t1 = _treatment(
        't1',
        isPrimary: true,
        total: 500000,
        pending: 200000,
      );
      final t2 = _treatment(
        't2',
        tipoBase: 'alineadores',
        total: 900000,
        pending: 500000,
        stage: TreatmentStage.retencion,
      );

      await _pumpTreatmentTab(
        tester,
        patient: patient,
        treatments: [t1, t2],
        financialItemsByTreatment: {
          't1': [_item('i1', 'Cuota inicial', 500000, 't1')],
          't2': [_item('i2', 'Alineadores Premium', 900000, 't2')],
        },
        historyByTreatment: {
          't1': [
            _history(
              'h1',
              't1',
              TreatmentStage.controles,
              notes: 'historial t1',
            ),
          ],
          't2': [
            _history(
              'h2',
              't2',
              TreatmentStage.retencion,
              notes: 'historial t2',
            ),
          ],
        },
      );

      expect(find.byKey(const ValueKey('treatment-stream-t1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('selected-treatment-title')),
        findsOneWidget,
      );
      expect(find.text('Cuota inicial'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('treatment-stream-t2')),
      );
      await tester.tap(find.byKey(const ValueKey('treatment-stream-t2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const ValueKey('selected-treatment-title')),
        findsOneWidget,
      );
      expect(find.text('Alineadores Premium'), findsOneWidget);
      expect(find.textContaining('Retención'), findsWidgets);
      expect(find.textContaining('900.000'), findsWidgets);
    },
  );
}

Future<void> _pumpTreatmentTab(
  WidgetTester tester, {
  required PatientModel patient,
  required List<PatientTreatment> treatments,
  required Map<String, List<FinancialItemModel>> financialItemsByTreatment,
  required Map<String, List<StageHistoryEntry>> historyByTreatment,
  List<StageHistoryEntry> legacyHistory = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientTreatmentsProvider(
          patient.id,
        ).overrideWith((ref) => Stream.value(treatments)),
        stageHistoryProvider(
          patient.id,
        ).overrideWith((ref) => Stream.value(legacyHistory)),
        ensureTreatmentFinancialItemsProvider.overrideWith(
          (ref) => (String patientId, PatientTreatment treatment) async {},
        ),
        for (final entry in financialItemsByTreatment.entries)
          treatmentFinancialItemsProvider((
            patientId: patient.id,
            treatmentId: entry.key,
          )).overrideWith((ref) => Stream.value(entry.value)),
        for (final entry in historyByTreatment.entries)
          treatmentStageHistoryProvider((
            patientId: patient.id,
            treatmentId: entry.key,
          )).overrideWith((ref) => Stream.value(entry.value)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            child: PatientTreatmentTab(patientId: patient.id, patient: patient),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
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

PatientTreatment _treatment(
  String id, {
  bool isPrimary = false,
  String tipoBase = 'convencional',
  TreatmentStage stage = TreatmentStage.controles,
  double total = 1000000,
  double pending = 400000,
}) {
  final now = DateTime(2026, 4, 21);
  return PatientTreatment(
    id: id,
    patientId: 'p1',
    nombre: 'Tratamiento $id',
    tipoBase: tipoBase,
    categoria: 'Ortodoncia',
    estado: 'activo',
    etapaActual: stage,
    fechaInicio: DateTime(2026, 1, 10),
    totalTratamiento: total,
    saldoPendiente: pending,
    isPrimary: isPrimary,
    createdAt: now.subtract(const Duration(days: 90)),
    updatedAt: now,
    createdBy: 'test',
  );
}

FinancialItemModel _item(
  String id,
  String name,
  double amount,
  String treatmentId,
) {
  final now = DateTime(2026, 4, 21);
  return FinancialItemModel(
    id: id,
    patientId: 'p1',
    treatmentId: treatmentId,
    name: name,
    normalizedName: FinancialItemModel.normalizeName(name),
    kind: 'extra',
    amount: amount,
    currency: 'COP',
    deletable: true,
    editableName: true,
    order: 1,
    active: true,
    createdByAdmin: true,
    createdAt: now,
    updatedAt: now,
  );
}

StageHistoryEntry _history(
  String id,
  String treatmentId,
  TreatmentStage stage, {
  String notes = 'nota',
}) {
  final now = DateTime(2026, 4, 21);
  return StageHistoryEntry(
    id: id,
    patientId: 'p1',
    treatmentId: treatmentId,
    etapaAnterior: TreatmentStage.valoracionInicial,
    etapaNueva: stage,
    esRetroceso: false,
    notas: notes,
    adminId: 'admin',
    fechaCambio: now,
  );
}
