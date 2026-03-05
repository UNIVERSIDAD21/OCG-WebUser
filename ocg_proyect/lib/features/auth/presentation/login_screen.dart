import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _error = null);

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OCG Clínica',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: OcgColors.espresso,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Panel de gestión clínica',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', color: OcgColors.bronze),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Ingresa tu correo';
                      if (!v.contains('@')) return 'Ingresa un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!authState.isLoading) {
                        _submit();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Ingresa tu contraseña';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  OcgButton(
                    label: 'Iniciar sesión',
                    onPressed: authState.isLoading ? null : _submit,
                    isLoading: authState.isLoading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: OcgColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push(RouteNames.forgotPassword),
                    child: const Text('¿Olvidaste tu contraseña?'),
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
