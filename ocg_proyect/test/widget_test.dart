import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/app/app.dart';

void main() {
  testWidgets('renderiza pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OcgApp()));
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
