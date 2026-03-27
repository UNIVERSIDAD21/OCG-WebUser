import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_button.dart';
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

  // ✅ NUEVO: bandera para mostrar mensaje de cuenta creada
  bool _showAccountCreatedBanner = false;

  @override
  void dispose() {
    super.dispose();
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
      setState(() {
        if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'user-not-found') {
          _error = 'Correo o contraseña incorrectos';
        } else if (e.code == 'user-disabled') {
          _error = 'Correo o contraseña incorrectos';
        } else if (e.code == 'network-request-failed') {
          _error = 'Sin conexión a internet. Verifica tu red.';
        } else {
          _error = '[${e.code}] ${e.message ?? 'No se pudo iniciar sesión.'}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
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

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──
                  Column(
                    children: [
                      const Text(
                        'OCG',
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        'Clínica Dental',
                        style: TextStyle(
                          fontSize: 13,
                          color: OcgColors.ink.withOpacity(0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ✅ NUEVO: Banner de cuenta creada exitosamente
                  if (_showAccountCreatedBanner) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF2E7D32),
                            size: 22,
                          ),
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
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF2E7D32),
                            ),
                            onPressed: () => setState(
                              () => _showAccountCreatedBanner = false,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Error ──
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OcgColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: OcgColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: OcgColors.error,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Formulario ──
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          onChanged: (v) => _email = v,
                          validator: Validators.email,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onChanged: (v) => _password = v,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa tu contraseña'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Botón iniciar sesión ──
                  OcgButton(
                    label: 'Iniciar sesión',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 16),

                  // ── Links ──
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push(RouteNames.forgotPassword),
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: OcgColors.bronze,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openRegisterDialog,
                            child: const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                color: OcgColors.espresso,
                                fontSize: 13,
                              ),
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
