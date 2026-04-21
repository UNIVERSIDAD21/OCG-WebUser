import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/dashboard/presentation/admin_modules_screens.dart';

void main() {
  group('Treatment KPI premium layout', () {
    testWidgets('se compacta con altura útil real sin overflow', (
      WidgetTester tester,
    ) async {
      Future<void> pumpKpi(double height) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TreatmentKpiPremiumTestHarness(
                  width: 210,
                  height: height,
                  value: r'$12.500.000',
                  title: 'Pagos vencidos',
                  subtitle: 'requieren seguimiento',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        _expectNoOverflow(tester);
      }

      await pumpKpi(110);
      expect(find.text('requieren seguimiento'), findsOneWidget);

      await pumpKpi(96);
      expect(find.text('requieren seguimiento'), findsOneWidget);

      await pumpKpi(80);
      _expectNoOverflow(tester);

      await pumpKpi(72);
      expect(find.text('requieren seguimiento'), findsNothing);
      _expectNoOverflow(tester);
    });

    testWidgets(
      'renderiza la sección KPI de pagos en desktop compacto sin overflow',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: PaymentsKpiSectionTestHarness(width: 500)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Saldo pendiente'), findsOneWidget);
        expect(find.text('Pagos vencidos'), findsOneWidget);
        _expectNoOverflow(tester);
      },
    );

    testWidgets(
      'renderiza la sección KPI de tratamientos en desktop compacto sin overflow',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: TreatmentsKpiSectionTestHarness(width: 500)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tratamientos activos'), findsOneWidget);
        expect(find.text('Ingresos totales'), findsOneWidget);
        _expectNoOverflow(tester);
      },
    );
  });
}

void _expectNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception != null) {
    expect(exception.toString(), isNot(contains('RenderFlex overflowed')));
  }
  expect(exception, isNull);
}
