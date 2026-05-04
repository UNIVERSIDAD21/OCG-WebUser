import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/admin/presentation/web/layout/admin_desktop_layout.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_dashboard_screen.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_patients_screen.dart';

void main() {
  const resolutions = <Size>[
    Size(1600, 900),
    Size(1440, 900),
    Size(1366, 768),
    Size(1280, 800),
    Size(1256, 1016),
    Size(1180, 820),
  ];

  testWidgets(
    'Dashboard desktop conserva estructura admin por tiers globales',
    (WidgetTester tester) async {
      for (final size in resolutions) {
        final layout = AdminDesktopLayoutData.fromViewport(size);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: size),
                child: Scaffold(
                  body: AdminDesktopLayoutScope(
                    layout: layout,
                    child: SizedBox(
                      width: layout.contentWidth,
                      child: const AdminDashboardDesktopTestHarness(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Agenda de hoy'), findsOneWidget);
        expect(find.text('Alertas operativas'), findsOneWidget);
        expect(find.text('Acceso rápido'), findsOneWidget);
        _expectNoOverflow(tester, 'dashboard $size');
      }
    },
  );

  testWidgets('Pacientes desktop comparte la misma gramática responsive', (
    WidgetTester tester,
  ) async {
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
                  child: const AdminPatientsDesktopTestHarness(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Pacientes'), findsOneWidget);
      expect(find.text('Gestión clínica y financiera'), findsOneWidget);
      expect(find.text('Nuevo paciente'), findsOneWidget);
      _expectNoOverflow(tester, 'patients $size');
    }
  });
}

void _expectNoOverflow(WidgetTester tester, String label) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: label);
}
