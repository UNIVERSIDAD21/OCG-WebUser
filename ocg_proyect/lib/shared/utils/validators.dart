class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  );

  static String? requiredField(String? value, {required String message}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!_emailRegex.hasMatch(v)) return 'Ingresa un correo válido';
    return null;
  }

  static String? passwordForLogin(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  static String? passwordForRegister(String? value) {
    final v = value ?? '';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Usa letras y números';
    }
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 3) return 'Ingresa un nombre válido';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '') != original) return 'Las contraseñas no coinciden';
    return null;
  }
}
