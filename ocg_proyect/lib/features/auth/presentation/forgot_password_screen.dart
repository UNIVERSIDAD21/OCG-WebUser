import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .resetPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _emailSent = true);
      _animCtrl.reset();
      _animCtrl.forward();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'Ingresa un correo válido.';
          break;
        case 'user-not-found':
          message = 'No existe una cuenta con ese correo.';
          break;
        case 'network-request-failed':
          message = 'Sin conexión a internet. Verifica tu red.';
          break;
        default:
          message = 'No se pudo enviar el enlace de recuperación.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: OcgColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo enviar el enlace de recuperación.'),
          backgroundColor: OcgColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEDE8DC),
                  Color(0xFFF5F0E6),
                  Color(0xFFE8E0D4),
                ],
              ),
            ),
          ),

          // ── Decorative elements ──
          Positioned(
            top: -100,
            right: -80,
            child: _DecoBlob(
              size: 320,
              color: const Color(0x4DC8AF8C),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _DecoBlob(
              size: 240,
              color: const Color(0x33B49B78),
            ),
          ),
          Positioned(
            top: 120,
            left: -40,
            child: _DecoBlob(
              size: 120,
              color: const Color(0x228C6239),
            ),
          ),

          // ── Floating dots ──
          const _FloatingDot(top: 180, right: 60, size: 4, delay: 0),
          const _FloatingDot(top: 260, right: 100, size: 3, delay: 800),
          const _FloatingDot(bottom: 200, left: 80, size: 5, delay: 1600),
          const _FloatingDot(bottom: 320, left: 50, size: 3, delay: 2400),

          // ── Content ──
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 460,
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: FadeTransition(
                        opacity: _fadeSlide,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(_fadeSlide),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ── Back button ──
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _AnimatedBackButton(),
                              ),
                              const SizedBox(height: 20),

                              // ── Glass Card ──
                              _GlassCard(
                                child: _emailSent
                                    ? _SuccessCardView(
                                        email: _emailCtrl.text.trim(),
                                        onBack: () => context.pop(),
                                      )
                                    : _FormCardView(
                                        formKey: _formKey,
                                        emailCtrl: _emailCtrl,
                                        loading: loading,
                                        onSubmit: _submit,
                                        onBack: () => context.pop(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM CARD
// ─────────────────────────────────────────────────────────────────────────────
class _FormCardView extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _FormCardView({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<_FormCardView> createState() => _FormCardViewState();
}

class _FormCardViewState extends State<_FormCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Animated icon ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final t = _pulseCtrl.value;
              final scale = 1.0 + 0.06 * (1 - t);
              final opacity = 0.25 + 0.15 * t;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC8AF8C).withOpacity(opacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFC8AF8C), Color(0xFFA88F6E)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC8AF8C).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Title ──
          const Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF2C2016),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle ──
          const Text(
            'Ingresa tu correo electrónico y te enviaremos\nun enlace seguro para restablecerla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8A6F59),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),

          // ── Email field ──
          _EmailField(
            controller: widget.emailCtrl,
            onSubmitted: widget.loading ? null : widget.onSubmit,
          ),
          const SizedBox(height: 26),

          // ── Submit button ──
          _SubmitButton(
            loading: widget.loading,
            onPressed: widget.onSubmit,
          ),
          const SizedBox(height: 20),

          // ── Back link ──
          _BackLink(onTap: widget.onBack),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessCardView extends StatefulWidget {
  final String email;
  final VoidCallback onBack;

  const _SuccessCardView({
    required this.email,
    required this.onBack,
  });

  @override
  State<_SuccessCardView> createState() => _SuccessCardViewState();
}

class _SuccessCardViewState extends State<_SuccessCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.elasticOut,
    ));
    _checkOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.easeOut,
    ));
    _checkCtrl.forward();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Animated check icon ──
        ScaleTransition(
          scale: _checkScale,
          child: FadeTransition(
            opacity: _checkOpacity,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Title ──
        const Text(
          '¡Enviado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF2C2016),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),

        // ── Email display ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0C7AF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 16,
                color: Color(0xFF8A6F59),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Instructions ──
        const Text(
          'Revisa tu bandeja de entrada y sigue\nel enlace para crear una nueva contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8A6F59),
            fontSize: 13,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 12),

        // ── Spam hint ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: const Color(0xFFA89078).withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Revisa spam si no lo ves en 2 minutos',
              style: TextStyle(
                color: const Color(0xFFA89078).withOpacity(0.8),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Back button ──
        _SubmitButton(
          loading: false,
          onPressed: widget.onBack,
          label: 'Volver al inicio de sesión',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _DecoBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _DecoBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

class _FloatingDot extends StatefulWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final int delay;

  const _FloatingDot({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.delay,
  });

  @override
  State<_FloatingDot> createState() => _FloatingDotState();
}

class _FloatingDotState extends State<_FloatingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final y = -4 + 8 * _anim.value;
        return Transform.translate(
          offset: Offset(0, y),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: const Color(0xFF8C6239).withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: const Color(0xFF6E5442).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Volver',
                style: TextStyle(
                  color: const Color(0xFF6E5442).withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7).withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFD9CCBE).withOpacity(0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.03),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const _EmailField({
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(
        color: Color(0xFF2C2016),
        fontSize: 14.5,
        letterSpacing: 0.1,
      ),
      decoration: InputDecoration(
        labelText: 'Correo electrónico',
        labelStyle: const TextStyle(
          color: Color(0xFF8A6F59),
          fontSize: 13.5,
        ),
        prefixIcon: const Icon(
          Icons.email_outlined,
          color: Color(0xFF8A6F59),
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFFF9F5EF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa tu correo';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Ingresa un correo válido';
        }
        return null;
      },
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  final String? label;

  const _SubmitButton({
    required this.loading,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C2016),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: const Color(0x202C2016),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label ?? 'Enviar enlace',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  final VoidCallback onTap;

  const _BackLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: Color(0xFF6E5442),
              ),
              const SizedBox(width: 8),
              const Text(
                'Volver al inicio de sesión',
                style: TextStyle(
                  color: Color(0xFF6E5442),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
