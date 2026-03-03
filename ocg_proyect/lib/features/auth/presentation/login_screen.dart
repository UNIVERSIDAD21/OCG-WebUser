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
    setState(() => _error = null);

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') {
          _error = 'Correo o contraseña incorrectos';
        } else if (e.code == 'network-request-failed') {
          _error = 'Sin conexión a internet. Verifica tu red.';
        } else {
          _error = e.message ?? 'No se pudo iniciar sesión.';
        }
      });
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
    }
  }

  Future<void> _openRegisterDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear cuenta de paciente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(authNotifierProvider.notifier).registerPatient(
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text,
                      displayName: nameCtrl.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuenta creada. Ya puedes iniciar sesión.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo crear la cuenta: $e')),
                  );
                }
              }
            },
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
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
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
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
                TextButton(
                  onPressed: _openRegisterDialog,
                  child: const Text('Crear cuenta de paciente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
