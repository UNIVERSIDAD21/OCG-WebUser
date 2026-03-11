import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_button.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _showAccountCreatedBanner = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Login ───────────────────────────────────────────────────────────────

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
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'user-not-found') {
          _error = 'Correo o contraseña incorrectos';
        } else if (e.code == 'network-request-failed') {
          _error = 'Sin conexión a internet. Verifica tu red.';
        } else {
          _error = '[${e.code}] ${e.message ?? 'No se pudo iniciar sesión.'}';
        }
      });
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
    }
  }

  // ─── Diálogo de registro ─────────────────────────────────────────────────
  //
  // ✅ ESTRATEGIA ANTI-RACE:
  //    El router puede detectar el authStateChange (cuenta creada) y destruir
  //    el contexto del diálogo antes de que podamos llamar Navigator.pop().
  //    Solución: capturar los datos del formulario, cerrar el diálogo CON
  //    Navigator.pop() PRIMERO, y solo después ejecutar registerPatient
  //    (que internamente ya hace signOut inmediato dentro del guard).
  //    Así el diálogo siempre se cierra limpiamente y la LoginScreen queda
  //    visible para mostrar el banner de éxito.

  Future<void> _openRegisterDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Resultado del diálogo: null = cancelado, Map = datos para registrar
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDs) => AlertDialog(
            title: const Text('Crear cuenta de paciente'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: Validators.fullName,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                      validator: Validators.passwordForRegister,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                      validator: (value) =>
                          Validators.confirmPassword(value, passCtrl.text),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(null);
                          }
                        });
                      },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        // ✅ Capturar datos antes de que los controladores
                        //    sean destruidos.
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'password': passCtrl.text,
                        };
                        // ✅ FIX WEB: Diferir el pop al siguiente frame para
                        //    que Flutter termine el ciclo de foco actual antes
                        //    de desmontar el diálogo. Evita el crash
                        //    "Cannot get renderObject of inactive element".
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(data);
                          }
                        });
                      },
                child: isSubmitting
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
          ),
        );
      },
    );

    // Limpiar controladores siempre
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();

    // Cancelado o contexto destruido
    if (result == null) return;
    if (!mounted) return;

    // ✅ El diálogo ya está cerrado. Ahora llamamos a registerPatient
    //    de forma segura. El método internamente hace signOut, por lo que
    //    el router nunca redirigirá al usuario a /patient/home.
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .registerPatient(
            email: result['email']!,
            password: result['password']!,
            displayName: result['name'],
          );

      if (mounted) {
        setState(() => _showAccountCreatedBanner = true);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este correo ya tiene una cuenta registrada.';
          break;
        case 'weak-password':
          msg = 'Contraseña muy débil (mín. 6 caracteres).';
          break;
        default:
          msg = '[${e.code}] ${e.message ?? 'Error desconocido.'}';
      }
      setState(() => _error = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear la cuenta. Intenta de nuevo.');
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

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
                  // ── Logo ──────────────────────────────────────────────────
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

                  // ── Banner cuenta creada ───────────────────────────────────
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
                              '¡Cuenta creada exitosamente!\nInicia sesión para continuar.',
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

                  // ── Error ─────────────────────────────────────────────────
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

                  // ── Formulario ────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: Validators.email,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
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
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa tu contraseña'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Botón iniciar sesión ───────────────────────────────────
                  OcgButton(
                    label: 'Iniciar sesión',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 16),

                  // ── Links ─────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () =>
                            context.push(RouteNames.forgotPassword),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: OcgColors.bronze,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : _openRegisterDialog,
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            color: OcgColors.espresso,
                            fontSize: 13,
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
