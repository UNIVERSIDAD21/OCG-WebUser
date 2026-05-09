import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_breakpoints.dart';
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

    final isDesktop = WebBreakpoints.isDesktop(context);

    if (isDesktop) {
      return _buildDesktop(context, isLoading);
    }
    return _buildMobile(context, isLoading);
  }

  Widget _buildDesktop(BuildContext context, bool isLoading) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: Stack(
        children: [
          const _DesktopGridBackground(),
          const _DesktopBlob(
            top: -120,
            right: -80,
            size: 420,
            color: Color(0x59C8AF8C),
          ),
          const _DesktopBlob(
            bottom: -100,
            left: -60,
            size: 350,
            color: Color(0x40B49B78),
          ),
          const _DesktopCenterGlow(),
          const _DesktopRing(delayMs: 0),
          const _DesktopRing(delayMs: 1650),
          const _DesktopRing(delayMs: 3300),
          const _DesktopScanLine(),
          const _DesktopViewportCorners(),
          SafeArea(
            child: Column(
              children: [
                const _DesktopStatusBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width >= 1440
                              ? 520
                              : 480,
                        ),
                        child: Column(
                          children: [
                            const _DesktopLogoHeader(),
                            const SizedBox(height: 18),
                            _DesktopGlassCard(
                              child: _buildLoginContent(
                                context,
                                isLoading,
                                includeFooterIndicator: false,
                                includeFooter: true,
                                showBrandHeader: false,
                                centerWelcomeTitle: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const _DesktopBottomBar(),
              ],
            ),
          ),
        ],
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
    // Posición vertical donde OCG queda centrado sobre la costura decorativa.
    const double seamY = 148.0;
    const double ocgFontSize = 56.0;
    final double ocgTop = seamY - (ocgFontSize / 2); // 120 px desde el top

    // La zona decorativa (_TopDeco + OCG superpuesto) ocupa 246 px en total.
    const double decoAreaHeight = 246.0;

    // Cuando el teclado está abierto se agrega su altura como padding inferior
    // para que el formulario pueda scrollear completamente sobre el teclado.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    // Altura mínima del scroll = pantalla − safe-area superior,
    // para que cuando no haya overflow el footer quede pegado abajo.
    final double screenH = MediaQuery.of(context).size.height;
    final double topPad = MediaQuery.of(context).padding.top;
    final double minH = screenH - topPad;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      // false → el teclado NO redimensiona el layout; nosotros compensamos
      // con padding inferior en el scroll.
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: true,
          bottom: false,
          child: SingleChildScrollView(
            // Todo (decoración + formulario + footer) scrollea JUNTO.
            // No hay nada "Positioned fijo" fuera del scroll.
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            child: ConstrainedBox(
              // minHeight garantiza que el Column llene la pantalla cuando
              // el contenido es corto (footer queda abajo sin gap raro).
              constraints: BoxConstraints(minHeight: minH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Zona decorativa ─────────────────────────────────────
                  // Stack LOCAL de altura fija: _TopDeco + OCG se superponen
                  // exactamente igual que antes, pero DENTRO del scroll.
                  // Al scrollear, todo sube junto sin romperse.
                  SizedBox(
                    height: decoAreaHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _TopDeco(),
                        ),
                        Positioned(
                          top: ocgTop,
                          left: 28,
                          right: 28,
                          child: const IgnorePointer(
                            child: _LoginBrandSeamLocked(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Formulario ──────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      0,
                      28,
                      // padding inferior = base + altura del teclado abierto.
                      16 + keyboardInset,
                    ),
                    child: _buildLoginContent(
                      context,
                      isLoading,
                      includeFooterIndicator: false,
                      includeFooter: false,
                      showBrandHeader: false,
                      centerWelcomeTitle: true,
                    ),
                  ),

                  // ── Footer ──────────────────────────────────────────────
                  // Siempre al final del scroll; queda visible debajo del
                  // formulario cuando no hay overflow.
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginContent(
    BuildContext context,
    bool isLoading, {
    required bool includeFooterIndicator,
    required bool includeFooter,
    required bool showBrandHeader,
    required bool centerWelcomeTitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBrandHeader) ...[
          _LoginBrandHeader(shiftUp: includeFooter ? 0 : 36),
          const SizedBox(height: 24),
        ],
        RichText(
          textAlign: centerWelcomeTitle ? TextAlign.center : TextAlign.left,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D1B0E),
              height: 1.25,
            ),
            children: [
              TextSpan(text: 'Estamos contigo\n'),
              TextSpan(
                text: 'en cada sonrisa',
                style: TextStyle(
                  color: Color(0xFF9A6A3B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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

class _DesktopGridBackground extends StatelessWidget {
  const _DesktopGridBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: _DesktopGridPainter()));
  }
}

class _DesktopGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 56.0;
    final paint = Paint()
      ..color = const Color(0x128C6239)
      ..strokeWidth = 1;

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DesktopBlob extends StatelessWidget {
  const _DesktopBlob({
    required this.size,
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final double size;
  final Color color;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
              stops: const [0, 0.72],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopCenterGlow extends StatelessWidget {
  const _DesktopCenterGlow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: 800,
          height: 800,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [const Color(0x108C6239), const Color(0x008C6239)],
              stops: const [0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopRing extends StatefulWidget {
  const _DesktopRing({required this.delayMs});

  final int delayMs;

  @override
  State<_DesktopRing> createState() => _DesktopRingState();
}

class _DesktopRingState extends State<_DesktopRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = Curves.easeOut.transform(_controller.value);
            final scale = 0.85 + (0.95 * t);
            final opacity = 0.45 * (1 - t);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x1F8C6239).withOpacity(opacity),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesktopScanLine extends StatefulWidget {
  const _DesktopScanLine();

  @override
  State<_DesktopScanLine> createState() => _DesktopScanLineState();
}

class _DesktopScanLineState extends State<_DesktopScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final h = MediaQuery.of(context).size.height;
        final y = (h + 4) * _controller.value - 2;
        return Positioned(
          left: 0,
          right: 0,
          top: y,
          child: IgnorePointer(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x668C6239),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopViewportCorners extends StatelessWidget {
  const _DesktopViewportCorners();

  @override
  Widget build(BuildContext context) {
    const border = BorderSide(color: Color(0x4D8C6239), width: 1.5);
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: 24,
            left: 24,
            child: _CornerBox(top: border, left: border),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: _CornerBox(top: border, right: border),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: _CornerBox(bottom: border, left: border),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: _CornerBox(bottom: border, right: border),
          ),
        ],
      ),
    );
  }
}

class _CornerBox extends StatelessWidget {
  const _CornerBox({this.top, this.right, this.bottom, this.left});

  final BorderSide? top;
  final BorderSide? right;
  final BorderSide? bottom;
  final BorderSide? left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top ?? BorderSide.none,
            right: right ?? BorderSide.none,
            bottom: bottom ?? BorderSide.none,
            left: left ?? BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _DesktopStatusBar extends StatelessWidget {
  const _DesktopStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1A8C6239))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF8C6239),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OCG',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2.8,
                  color: Color(0x733D230C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'ACCESO SEGURO',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.2,
              color: Color(0x473D230C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLogoHeader extends StatelessWidget {
  const _DesktopLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'OCG',
          style: TextStyle(
            fontFamily: 'Cormorant Garamond',
            fontSize: 66,
            fontWeight: FontWeight.w600,
            letterSpacing: 13,
            color: Color(0xFF2D1B0E),
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'CLÍNICA DENTAL',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 4.0,
            color: Color(0xFF8C6239),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0x738C6239),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopGlassCard extends StatelessWidget {
  const _DesktopGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(52, 38, 52, 34),
      decoration: BoxDecoration(
        color: const Color(0xE0FAF6EF),
        border: Border.all(color: const Color(0x2E8C6239)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A8C6239), blurRadius: 6),
          BoxShadow(
            color: Color(0x1F644119),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.2,
                    colors: [Color(0x148C6239), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _CardTopShimmer()),
          const Positioned(
            top: 2,
            left: 2,
            child: _CardCorner(top: true, left: true),
          ),
          const Positioned(
            top: 2,
            right: 2,
            child: _CardCorner(top: true, right: true),
          ),
          const Positioned(
            bottom: 2,
            left: 2,
            child: _CardCorner(bottom: true, left: true),
          ),
          const Positioned(
            bottom: 2,
            right: 2,
            child: _CardCorner(bottom: true, right: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CardTopShimmer extends StatelessWidget {
  const _CardTopShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0x808C6239), Colors.transparent],
        ),
      ),
    );
  }
}

class _CardCorner extends StatelessWidget {
  const _CardCorner({
    this.top = false,
    this.right = false,
    this.bottom = false,
    this.left = false,
  });

  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Color(0x668C6239), width: 1.5);
    return SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            right: right ? side : BorderSide.none,
            bottom: bottom ? side : BorderSide.none,
            left: left ? side : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _DesktopBottomBar extends StatelessWidget {
  const _DesktopBottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1A8C6239))),
      ),
      child: const Center(
        child: SizedBox(
          width: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x598C6239), width: 1.2),
              ),
            ),
          ),
        ),
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
            child: _DecoCircle(size: 240, color: Color(0x1F8C6239)),
          ),
          Positioned(
            top: -55,
            right: 0,
            child: _DecoCircle(size: 180, color: Color(0x178C6239)),
          ),
          Positioned(
            bottom: -20,
            left: -50,
            child: _DecoCircle(size: 160, color: Color(0x66DDD0BC)),
          ),
          Positioned.fill(child: CustomPaint(painter: _TopWavePainter())),
          const Positioned(
            top: 28,
            right: 36,
            child: _DecoCircle(size: 5, color: Color(0x8F8C6239)),
          ),
          const Positioned(
            top: 44,
            right: 52,
            child: _DecoCircle(size: 3, color: Color(0x728C6239)),
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
      ..color = const Color(0xE0C8B293)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

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
      child: const _LoginBrandSeamLocked(),
    );
  }
}

class _LoginBrandSeamLocked extends StatelessWidget {
  const _LoginBrandSeamLocked();

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
      height: 1.4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: leftToRight ? Alignment.centerLeft : Alignment.centerRight,
          end: leftToRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Colors.transparent, Color(0xFFB8946D)],
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
      height: 1.4,
      color: const Color(0xFF8C6239).withOpacity(0.92),
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
        color: const Color(0xFF8C6239).withOpacity(0.95),
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
  bool _obscurePass = true;
  bool _obscureConfirm = true;

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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF8A6F59),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF8A6F59), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9F5EF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0C7AF), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC8AF8C), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFCF8), Color(0xFFF7F0E8)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7DDD2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C2016).withOpacity(0.1),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC8AF8C), Color(0xFFA88F6E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear cuenta',
                            style: TextStyle(
                              color: Color(0xFF2C2016),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Regístrate como paciente OCG',
                            style: TextStyle(
                              color: Color(0xFF8A6F59),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Name field
                TextFormField(
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    label: 'Nombre completo',
                    icon: Icons.person_outline_rounded,
                  ),
                  onChanged: (v) => _name = v,
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 14),
                // Email field
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                  ),
                  onChanged: (v) => _email = v,
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                // Password field
                TextFormField(
                  obscureText: _obscurePass,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    label: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF8A6F59),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  onChanged: (v) => _pass = v,
                  validator: Validators.passwordForRegister,
                ),
                const SizedBox(height: 14),
                // Confirm password field
                TextFormField(
                  obscureText: _obscureConfirm,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    label: 'Confirmar contraseña',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF8A6F59),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  onChanged: (v) => _confirm = v,
                  validator: (value) => Validators.confirmPassword(value, _pass),
                ),
                // Error message
                if (_registerError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD32F2F).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFD32F2F),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _registerError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6E5442),
                          side: const BorderSide(color: Color(0xFFD9CCBE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2016),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear cuenta',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
