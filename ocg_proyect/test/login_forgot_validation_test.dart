import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/auth/presentation/forgot_password_screen.dart';
import 'package:ocg_proyect/features/auth/presentation/login_screen.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('Login muestra validaciones de correo y contraseña vacíos', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Login muestra validación de correo inválido', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.enterText(find.byType(TextFormField).at(0), 'abc@');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('Forgot password valida correo vacío', (tester) async {
    await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));

    await tester.tap(find.text('Enviar enlace de recuperación'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
  });
}
