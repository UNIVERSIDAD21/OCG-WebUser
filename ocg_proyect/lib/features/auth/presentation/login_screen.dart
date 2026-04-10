import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/validators.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String _email = '';
  String _password = '';
  bool _obscure = true;
  String? _error;
  int _errorVersion = 0;
  bool _showAccountCreatedBanner = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _emailFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _passwordFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
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
        _setTransientError(
          '[${e.code}] ${e.message ?? 'No se pudo iniciar sesión.'}',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _setTransientError('No se pudo iniciar sesión. Intenta de nuevo.');
    }
  }

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

    if (isDesktop) {
      return _buildDesktop(context, isLoading);
    }
    return _buildMobile(context, isLoading);
  }

  Widget _buildDesktop(BuildContext context, bool isLoading) {
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
                  color: const Color(0xFFF7F3EC),
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
                child: _buildLoginContent(
                  context,
                  isLoading,
                  includeFooterIndicator: false,
                  includeFooter: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT — reestructurado para distribución vertical equilibrada.
  //
  // Problema anterior: el Column dentro del SingleChildScrollView no tenía
  // altura mínima garantizada → el contenido se apilaba arriba y dejaba un
  // hueco enorme antes del footer fijo.
  //
  // Solución estructural:
  //  • LayoutBuilder captura la altura real disponible para el área scrolleable.
  //  • ConstrainedBox(minHeight: constraints.maxHeight) fuerza al área a
  //    ocupar al menos toda esa altura.
  //  • MainAxisAlignment.center dentro del Column scrolleable centra el bloque
  //    de login verticalmente cuando hay espacio libre.
  //  • Si el teclado aparece y el contenido ya no cabe, SingleChildScrollView
  //    habilita el scroll sin romper nada.
  //  • El footer está fuera del área scrolleable, siempre anclado abajo.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context, bool isLoading) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      // resizeToAvoidBottomInset por defecto es true; el Scaffold sube el
      // contenido cuando aparece el teclado, lo que permite que el
      // LayoutBuilder recalcule la altura disponible correctamente.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Decoración superior — permanece fija en el Stack.
            const Positioned(top: 0, left: 0, right: 0, child: _TopDeco()),

            // Columna raíz: área scrolleable + footer fijo.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Área scrolleable ──────────────────────────────────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        // ConstrainedBox garantiza que aunque el contenido
                        // sea pequeño, el Column interno siempre intente
                        // ocupar la altura completa disponible.
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Con top SafeArea activo, dejamos una base
                                // corta y elevamos el contenido para que el
                                // wordmark OCG cruce la unión deco/contenido.
                                const SizedBox(height: 24),
                                Transform.translate(
                                  offset: const Offset(0, -34),
                                  child: _buildLoginContent(
                                    context,
                                    isLoading,
                                    includeFooterIndicator: false,
                                    includeFooter: false,
                                  ),
                                ),
                                // Compensación inferior por el translate.
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Footer fijo al fondo ───────────────────────────────────
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: const _LoginFooter(showIndicator: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginContent(
    BuildContext context,
    bool isLoading, {
    required bool includeFooterIndicator,
    required bool includeFooter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LoginBrandHeader(shiftUp: includeFooter ? 0 : 24),
        const SizedBox(height: 24),
        const Text(
          'Estamos contigo\nen cada sonrisa',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D1B0E),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Consulta tus citas, avances y detalles de tu tratamiento desde tu cuenta.',
          style: TextStyle(
            fontSize: 13.5,
            color: const Color(0xFF5C4A3A).withOpacity(0.75),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
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
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2D1B0E),
                  letterSpacing: 0.15,
                ),
                decoration: _fieldDecoration(
                  hint: 'Correo electrónico',
                  icon: Icons.email_outlined,
                  isFocused: _emailFocus.hasFocus,
                  hasValue: _email.trim().isNotEmpty,
                ),
                onChanged: (v) {
                  setState(() => _email = v);
                },
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                focusNode: _passwordFocus,
                obscureText: _obscure,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2D1B0E),
                  letterSpacing: 0.15,
                ),
                decoration: _fieldDecoration(
                  hint: 'Contraseña',
                  icon: Icons.lock_outline,
                  isFocused: _passwordFocus.hasFocus,
                  hasValue: _password.isNotEmpty,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: (_passwordFocus.hasFocus || _password.isNotEmpty)
                          ? const Color(0xFF8C6239)
                          : const Color(0xFFDDD0BC),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (v) {
                  setState(() => _password = v);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D1B0E),
                    foregroundColor: const Color(0xFFF7F3EC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0x302D1B0E),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF7F3EC),
                          ),
                        )
                      : const Text('INICIAR SESIÓN'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: () => context.push(RouteNames.forgotPassword),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: const Color(0xFF5C4A3A).withOpacity(0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openRegisterDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
              child: const Text(
                'Crear cuenta',
                style: TextStyle(
                  color: Color(0xFF8C6239),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (includeFooter) ...[
          SizedBox(height: includeFooterIndicator ? 32 : 14),
          _LoginFooter(showIndicator: includeFooterIndicator),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    required bool isFocused,
    required bool hasValue,
    Widget? suffix,
  }) {
    final borderColor = isFocused
        ? const Color(0xFF8C6239)
        : hasValue
        ? const Color(0xFF5C4A3A)
        : const Color(0xFFDDD0BC);

    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: isFocused ? 1.5 : 1),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0A090), fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF7F3EC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      prefixIcon: Icon(
        icon,
        color: (isFocused || hasValue)
            ? const Color(0xFF8C6239)
            : const Color(0xFFDDD0BC),
        size: 18,
      ),
      suffixIcon: suffix,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC0392B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC0392B), width: 1.4),
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFFC0392B),
        height: 1.2,
      ),
    );
  }
}

class _TopDeco extends StatelessWidget {
  const _TopDeco();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x36DDD0BC), Color(0xFFF7F3EC)],
                stops: [0, 0.6],
              ),
            ),
          ),
          Positioned(
            top: -85,
            right: -30,
            child: _DecoCircle(size: 240, color: Color(0x128C6239)),
          ),
          Positioned(
            top: -55,
            right: 0,
            child: _DecoCircle(size: 180, color: Color(0x0D8C6239)),
          ),
          Positioned(
            bottom: -20,
            left: -50,
            child: _DecoCircle(size: 160, color: Color(0x4ADDD0BC)),
          ),
          Positioned.fill(child: CustomPaint(painter: _TopWavePainter())),
          const Positioned(
            top: 28,
            right: 36,
            child: _DecoCircle(size: 5, color: Color(0x738C6239)),
          ),
          const Positioned(
            top: 44,
            right: 52,
            child: _DecoCircle(size: 3, color: Color(0x5A8C6239)),
          ),
        ],
      ),
    );
  }
}

class _DecoCircle extends StatelessWidget {
  const _DecoCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xC4D2C1A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final path = Path()
      ..moveTo(20, size.height - 30)
      ..quadraticBezierTo(
        size.width / 2,
        size.height - 80,
        size.width - 20,
        size.height - 30,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({this.shiftUp = 0});

  final double shiftUp;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -shiftUp),
      child: Column(
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
              color: Color(0xFF2D1B0E),
              letterSpacing: 10,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CLÍNICA DENTAL',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF8C6239),
              letterSpacing: 3.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _SepLine(leftToRight: true),
              _SepLine(leftToRight: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _SepLine extends StatelessWidget {
  const _SepLine({required this.leftToRight});

  final bool leftToRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: leftToRight ? Alignment.centerLeft : Alignment.centerRight,
          end: leftToRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Colors.transparent, Color(0xFFC9B295)],
        ),
      ),
    );
  }
}

class _DecoLine extends StatelessWidget {
  const _DecoLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 1.0,
      color: const Color(0xFF8C6239).withOpacity(0.78),
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
        color: const Color(0xFF8C6239).withOpacity(0.78),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.showIndicator});

  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '© 2026 OCG Clínica Dental · Todos los derechos reservados',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: const Color(0xFF5C4A3A).withOpacity(0.4),
            letterSpacing: 0.2,
          ),
        ),
        if (showIndicator) ...[
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B0E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
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
        color: const Color(0x14C0392B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x52C0392B)),
      ),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1A0F6E56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4D0F6E56)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Color(0xFF0F6E56)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '¡Tu cuenta ha sido creada exitosamente! Inicia sesión para continuar.',
              style: TextStyle(color: Color(0xFF0F6E56), fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF0F6E56)),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _registerError = null;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .registerPatient(
            email: _email.trim(),
            password: _pass,
            displayName: _name.trim(),
          );

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
