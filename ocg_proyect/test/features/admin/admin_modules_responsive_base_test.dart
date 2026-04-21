import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/admin/presentation/web/layout/admin_desktop_layout.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_modules_screens.dart';

void main() {
  const resolutions = <Size>[
    Size(1600, 900),
    Size(1440, 900),
    Size(1366, 768),
    Size(1280, 800),
    Size(1256, 1016),
    Size(1180, 820),
  ];

  testWidgets('KPIs de pagos responden por tiers sin overflow', (
    WidgetTester tester,
  ) async {
    for (final size in resolutions) {
      final layout = AdminDesktopLayoutData.fromViewport(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDesktopLayoutScope(
              layout: layout,
              child: SizedBox(
                width: layout.contentWidth,
                child: PaymentsKpiSectionTestHarness(
                  width: layout.contentWidth,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Saldo pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'payments $size');
    }
  });

  testWidgets('KPIs de tratamientos responden por tiers sin overflow', (
    WidgetTester tester,
  ) async {
    for (final size in resolutions) {
      final layout = AdminDesktopLayoutData.fromViewport(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDesktopLayoutScope(
              layout: layout,
              child: SizedBox(
                width: layout.contentWidth,
                child: TreatmentsKpiSectionTestHarness(
                  width: layout.contentWidth,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tratamientos activos'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'treatments $size');
    }
  });
}
