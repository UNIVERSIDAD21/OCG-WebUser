import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/admin/presentation/web/layout/admin_desktop_layout.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_appointments_screen.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_dashboard_screen.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_modules_screens.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_patients_screen.dart';
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

  final modules = <String, Widget Function(Size)>{
    'dashboard': (_) => const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: AdminDashboardDesktopTestHarness()),
      ),
    ),
    'pacientes': (_) => const MaterialApp(
      home: Scaffold(body: AdminPatientsDesktopTestHarness()),
    ),
    'agenda': (_) => const MaterialApp(
      home: Scaffold(body: AdminAppointmentsDesktopTestHarness()),
    ),
    'tratamientos': (_) => const MaterialApp(
      home: Scaffold(body: AdminTreatmentsDesktopTestHarness()),
    ),
    'pagos': (_) => const MaterialApp(
      home: Scaffold(body: AdminPaymentsDesktopTestHarness()),
    ),
    'simulador': (_) => const MaterialApp(
      home: Scaffold(body: AdminSimulatorDesktopTestHarness()),
    ),
    'detalle': (_) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 900,
          child: PatientDetailDesktopWorkspaceTestHarness(patient: patient),
        ),
      ),
    ),
  };

  testWidgets('matriz oficial desktop admin validada para todos los módulos', (
    WidgetTester tester,
  ) async {
    for (final entry in modules.entries) {
      for (final size in resolutions) {
        final layout = AdminDesktopLayoutData.fromViewport(size);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: AdminDesktopLayoutScope(
              layout: layout,
              child: SizedBox(
                width: layout.contentWidth,
                child: entry.value(size),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${entry.key} @ $size');
      }
    }
  });
}
