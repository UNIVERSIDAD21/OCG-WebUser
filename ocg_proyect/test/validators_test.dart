import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/shared/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('correo vacío', () {
      expect(Validators.email(''), 'Ingresa tu correo');
    });

    test('correo inválido', () {
      expect(Validators.email('abc@'), 'Ingresa un correo válido');
    });

    test('correo válido', () {
      expect(Validators.email('test@example.com'), isNull);
    });
  });

  group('Validators.passwordForLogin', () {
    test('password vacía', () {
      expect(Validators.passwordForLogin(''), 'Ingresa tu contraseña');
    });

    test('password no vacía', () {
      expect(Validators.passwordForLogin('123456'), isNull);
    });
  });

  group('Validators registro', () {
    test('nombre corto bloqueado', () {
      expect(Validators.fullName('ab'), 'Ingresa un nombre válido');
    });

    test('password < 6 bloqueada', () {
      expect(Validators.passwordForRegister('a1b2'), 'Mínimo 6 caracteres');
    });

    test('password sin letras y números bloqueada', () {
      expect(Validators.passwordForRegister('abcdef'), 'Usa letras y números');
      expect(Validators.passwordForRegister('123456'), 'Usa letras y números');
    });

    test('confirmación distinta bloqueada', () {
      expect(Validators.confirmPassword('abc123', 'abc124'), 'Las contraseñas no coinciden');
    });
  });
}
