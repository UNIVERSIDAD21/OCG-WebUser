import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/admin/presentation/web/layout/admin_desktop_layout.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/patients/presentation/patient_detail_screen.dart';

void main() {
  const resolutions = <Size>[
    Size(1600, 900),
    Size(1440, 900),
    Size(1366, 768),
    Size(1280, 800),
    Size(1256, 1016),
    Size(1180, 820),
  ];

  testWidgets('workspace desktop del detalle mantiene identidad por tiers', (
    WidgetTester tester,
  ) async {
    final patient = PatientModel(
      id: 'p1',
      nombre: 'Erik Sebastian',
      email: 'erik@example.com',
      telefono: '3000000000',
      fechaNacimiento: DateTime(1990, 1, 1),
      tipoTratamiento: TreatmentType.convencional,
      etapaActual: TreatmentStage.controles,
      fechaInicio: DateTime(2026, 1, 10),
      notasClinicas: 'Paciente demo',
      totalTratamiento: 4800000,
      saldoPendiente: 1200000,
      createdAt: DateTime(2026, 1, 10),
      updatedAt: DateTime(2026, 4, 21),
    );

    for (final size in resolutions) {
      final layout = AdminDesktopLayoutData.fromViewport(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: AdminDesktopLayoutScope(
                layout: layout,
                child: SizedBox(
                  width: layout.contentWidth,
                  height: 900,
                  child: PatientDetailDesktopWorkspaceTestHarness(
                    patient: patient,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Workspace clínico, financiero y operativo del paciente'),
        findsOneWidget,
      );
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Tratamiento'), findsOneWidget);
      expect(find.text('Simulador'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
