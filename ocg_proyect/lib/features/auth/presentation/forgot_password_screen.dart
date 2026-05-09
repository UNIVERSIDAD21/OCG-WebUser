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

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
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
          // Background gradient
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
          // Decorative blobs
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC8AF8C).withOpacity(0.35),
                    const Color(0xFFC8AF8C).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB49B78).withOpacity(0.25),
                    const Color(0xFFB49B78).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF6E5442),
                          ),
                          tooltip: 'Volver',
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Glass card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFD9CCBE).withOpacity(0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C2016).withOpacity(0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _emailSent
                            ? _buildSuccessState()
                            : _buildFormState(loading),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(bool loading) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC8AF8C), Color(0xFFA88F6E)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC8AF8C).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Text(
            'Recuperar contraseña',
            style: TextStyle(
              color: Color(0xFF2C2016),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo y te enviaremos\nun enlace para restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8A6F59),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Email field
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!loading) _submit();
            },
            style: const TextStyle(
              color: Color(0xFF2C2016),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: const TextStyle(
                color: Color(0xFF8A6F59),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Color(0xFF8A6F59),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF9F5EF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE0C7AF),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFC8AF8C),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFD32F2F),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFD32F2F),
                  width: 2,
                ),
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
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2016),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enviar enlace',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Back to login link
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: Color(0xFF6E5442),
            ),
            label: const Text(
              'Volver al inicio de sesión',
              style: TextStyle(
                color: Color(0xFF6E5442),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF639922), Color(0xFF4A7A18)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF639922).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '¡Enlace enviado!',
          style: TextStyle(
            color: Color(0xFF2C2016),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Revisa tu correo\n${_emailCtrl.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8A6F59),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Si no ves el correo, revisa tu carpeta\nde spam o correo no deseado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFA89078),
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2016),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Volver al inicio de sesión',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
