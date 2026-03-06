import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_button.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de recuperación enviado.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'No se pudo enviar el enlace de recuperación.';

      if (e.code == 'invalid-email') {
        message = 'Ingresa un correo válido.';
      } else if (e.code == 'user-not-found') {
        message = 'No existe una cuenta con ese correo.';
      } else if (e.code == 'network-request-failed') {
        message = 'Sin conexión a internet. Verifica tu red.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el enlace de recuperación.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Ingresa tu correo para enviarte un enlace de recuperación.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!loading) {
                        _submit();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  OcgButton(
                    label: 'Enviar enlace de recuperación',
                    onPressed: loading ? null : _submit,
                    isLoading: loading,
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
