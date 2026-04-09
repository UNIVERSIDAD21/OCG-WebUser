import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../../../shared/utils/dialog_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _obscure = true;
  String? _error;
  int _errorVersion = 0;

  // ✅ NUEVO: bandera para mostrar mensaje de cuenta creada
  bool _showAccountCreatedBanner = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _setTransientError(String message) {
    _errorVersion++;
    final currentVersion = _errorVersion;
    setState(() => _error = message);

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_errorVersion != currentVersion) return;
      setState(() => _error = null);
    });
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _error = null;
      _showAccountCreatedBanner = false;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signIn(_email.trim(), _password);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        _setTransientError('Correo o contraseña incorrectos');
      } else if (e.code == 'user-disabled') {
        _setTransientError('Correo o contraseña incorrectos');
      } else if (e.code == 'network-request-failed') {
        _setTransientError('Sin conexión a internet. Verifica tu red.');
      } else {
        _setTransientError('[${e.code}] ${e.message ?? 'No se pudo iniciar sesión.'}');
      }
    } catch (_) {
      if (!mounted) return;
      _setTransientError('No se pudo iniciar sesión. Intenta de nuevo.');
    }
  }

  // ─── Diálogo de registro ─────────────────────────────────────────────────
  //
  // Después de crear la cuenta se hace sign-out inmediato,
  //    se muestra un banner de éxito y el usuario debe iniciar sesión
  //    manualmente (flujo correcto para un sistema clínico).

  Future<void> _openRegisterDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RegisterPatientDialog(),
    ).then((created) {
      if (created == true && mounted) {
        setState(() => _showAccountCreatedBanner = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final sessionError = ref.watch(authInvalidSessionMessageProvider);

    if (sessionError != null && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setTransientError(sessionError);
        ref.read(authInvalidSessionMessageProvider.notifier).set(null);
      });
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LoginBrandHeader(),
        const SizedBox(height: 28),
        const Text(
          'Bienvenido de nuevo',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: OcgColors.espresso,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Accede a tu cuenta para gestionar tus citas y tratamientos.',
          style: TextStyle(
            fontSize: 13.5,
            color: OcgColors.ink.withOpacity(0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        if (_showAccountCreatedBanner) ...[
          _SuccessBanner(
            onClose: () => setState(() => _showAccountCreatedBanner = false),
          ),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...[
          _ErrorBanner(error: _error!),
          const SizedBox(height: 14),
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration(
                  hint: 'Correo electrónico',
                  icon: Icons.email_outlined,
                ),
                onChanged: (v) => _email = v,
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                obscureText: _obscure,
                decoration: _fieldDecoration(
                  hint: 'Contraseña',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFFDDD0BC),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (v) => _password = v,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: OcgColors.espresso,
              foregroundColor: OcgColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OcgColors.ivory,
                    ),
                  )
                : const Text('INICIAR SESIÓN'),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: () => context.push(RouteNames.forgotPassword),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: OcgColors.ink.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openRegisterDialog,
              child: const Text(
                'Crear cuenta',
                style: TextStyle(
                  color: OcgColors.bronze,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          '© 2026 OCG Clínica Dental · Todos los derechos reservados',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: OcgColors.ink.withOpacity(0.4),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8E4DD),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  decoration: BoxDecoration(
                    color: OcgColors.ivory,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFC8BFB0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E2D1B0E),
                        blurRadius: 48,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: formContent,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -50,
              right: -50,
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x36DDD0BC), OcgColors.ivory],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 90,
              left: 20,
              right: 20,
              child: CustomPaint(
                painter: _TopArcPainter(),
                size: const Size(double.infinity, 80),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formContent,
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: OcgColors.espresso.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDD0BC)),
    );

    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: OcgColors.ivory,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      prefixIcon: Icon(icon, color: const Color(0xFFDDD0BC)),
      suffixIcon: suffix,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: OcgColors.bronze, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: OcgColors.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: OcgColors.error, width: 1.4),
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _DecoLine(),
            SizedBox(width: 10),
            _DecoDot(),
            SizedBox(width: 10),
            _DecoLine(),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'OCG',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 56,
            fontWeight: FontWeight.w600,
            color: OcgColors.espresso,
            letterSpacing: 8,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'CLÍNICA DENTAL',
          style: TextStyle(
            fontSize: 10,
            color: OcgColors.bronze,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }
}

class _DecoLine extends StatelessWidget {
  const _DecoLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 1,
      color: OcgColors.bronze.withOpacity(0.5),
    );
  }
}

class _DecoDot extends StatelessWidget {
  const _DecoDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: OcgColors.bronze.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.error.withOpacity(0.3)),
      ),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(color: OcgColors.error, fontSize: 13),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '¡Tu cuenta ha sido creada exitosamente!\nInicia sesión para continuar.',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF2E7D32)),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _TopArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x66DDD0BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(0, 56)
      ..quadraticBezierTo(size.width / 2, 8, size.width, 56);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegisterPatientDialog extends ConsumerStatefulWidget {
  const _RegisterPatientDialog();

  @override
  ConsumerState<_RegisterPatientDialog> createState() =>
      _RegisterPatientDialogState();
}

class _RegisterPatientDialogState
    extends ConsumerState<_RegisterPatientDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _registerError;

  String _name = '';
  String _email = '';
  String _pass = '';
  String _confirm = '';

  // DESPUÉS — signOut inmediato antes de cerrar el diálogo:
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _registerError = null;
    });

    try {
      // 1. Crear la cuenta (esto hace auto-login internamente)
      await ref
          .read(authNotifierProvider.notifier)
          .registerPatient(
            email: _email.trim(),
            password: _pass,
            displayName: _name.trim(),
          );

      // 2. Cerrar el diálogo pasando true para activar el banner
      if (!mounted) return;
      popDialog(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _registerError = e.code == 'email-already-in-use'
            ? 'Este correo ya está en uso.'
            : 'No se pudo crear la cuenta [${e.code}].';
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _registerError = e.code == 'already-exists'
            ? 'Este correo ya está en uso.'
            : (e.message ?? 'No se pudo crear la cuenta.');
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        final code = e.code.toLowerCase();
        _registerError = code.contains('already') || code.contains('in-use')
            ? 'Este correo ya está en uso.'
            : (e.message ?? 'No se pudo crear la cuenta. Intenta de nuevo.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _registerError = 'No se pudo crear la cuenta. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear cuenta de paciente'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                onChanged: (v) => _name = v,
                validator: Validators.fullName,
              ),
              const SizedBox(height: 10),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onChanged: (v) => _email = v,
                onSaved: (v) => _email = v?.trim() ?? '',
                validator: Validators.email,
              ),
              const SizedBox(height: 10),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                onChanged: (v) => _pass = v,
                validator: Validators.passwordForRegister,
              ),
              const SizedBox(height: 10),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                onChanged: (v) => _confirm = v,
                validator: (value) => Validators.confirmPassword(value, _pass),
              ),
              if (_registerError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _registerError!,
                  style: const TextStyle(color: OcgColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OcgColors.espresso,
            foregroundColor: OcgColors.ivory,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OcgColors.ivory,
                  ),
                )
              : const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
