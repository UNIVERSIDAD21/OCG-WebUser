import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/treatment/data/models/patient_treatment.dart';
import 'package:ocg_proyect/features/treatment/presentation/widgets/manage_patient_treatment_dialog.dart';

void main() {
  Widget buildDialog(PatientTreatment? initialTreatment) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ManagePatientTreatmentDialog(
            patientId: 'patient-1',
            initialTreatment: initialTreatment,
          ),
        ),
      ),
    );
  }

  testWidgets('exige subtipo para tratamiento convencional', (tester) async {
    final treatment = PatientTreatment(
      id: 'tx-1',
      patientId: 'patient-1',
      nombre: 'Convencional',
      categoria: 'ortodoncia',
      tipoBase: 'convencional',
      estado: 'activo',
      etapaActual: TreatmentStage.valoracionInicial,
      fechaInicio: DateTime(2026, 4, 1),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      isPrimary: true,
      createdBy: 'admin-1',
      updatedBy: 'admin-1',
    );

    await tester.pumpWidget(buildDialog(treatment));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Subtipo obligatorio'), findsOneWidget);
    expect(find.text('Debes elegir un subtipo (Estético o Metálico).'), findsOneWidget);
  });

  testWidgets('exige subtipo para tratamiento autoligado', (tester) async {
    final treatment = PatientTreatment(
      id: 'tx-2',
      patientId: 'patient-1',
      nombre: 'Autoligado',
      categoria: 'ortodoncia',
      tipoBase: 'autoligado',
      estado: 'activo',
      etapaActual: TreatmentStage.valoracionInicial,
      fechaInicio: DateTime(2026, 4, 1),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      isPrimary: false,
      createdBy: 'admin-1',
      updatedBy: 'admin-1',
    );

    await tester.pumpWidget(buildDialog(treatment));

    expect(find.text('Subtipo obligatorio'), findsOneWidget);
    expect(find.text('Para Convencional y Autoligado debes elegir Estético o Metálico.'), findsOneWidget);
  });

  testWidgets('permite tratamiento sin subtipo cuando no aplica', (tester) async {
    final treatment = PatientTreatment(
      id: 'tx-3',
      patientId: 'patient-1',
      nombre: 'Alineadores',
      categoria: 'ortodoncia',
      tipoBase: 'alineadores',
      estado: 'activo',
      etapaActual: TreatmentStage.valoracionInicial,
      fechaInicio: DateTime(2026, 4, 1),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      isPrimary: false,
      createdBy: 'admin-1',
      updatedBy: 'admin-1',
    );

    await tester.pumpWidget(buildDialog(treatment));

    expect(find.text('Subtipo obligatorio'), findsNothing);
    expect(find.text('Debes elegir un subtipo (Estético o Metálico).'), findsNothing);
  });
}
