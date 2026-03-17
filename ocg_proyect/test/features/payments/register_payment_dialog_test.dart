import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/presentation/widgets/register_payment_dialog.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const RegisterPaymentDialog(
                patientId: 'p-1',
                saldoPendiente: 100,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('validación de monto vacío', (tester) async {
    await openDialog(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar pago'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa el monto'), findsOneWidget);
  });

  testWidgets('validación de monto cero', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar pago'));
    await tester.pumpAndSettle();

    expect(find.text('El monto debe ser mayor a cero'), findsOneWidget);
  });

  testWidgets('validación de monto mayor al saldo', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, '150');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar pago'));
    await tester.pumpAndSettle();

    expect(find.text('El monto no puede superar el saldo pendiente'), findsOneWidget);
  });

  testWidgets('muestra banner de deuda saldada cuando monto == saldo', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.pumpAndSettle();

    expect(
      find.text('Este pago saldará la deuda completa del paciente.'),
      findsOneWidget,
    );
  });
}
