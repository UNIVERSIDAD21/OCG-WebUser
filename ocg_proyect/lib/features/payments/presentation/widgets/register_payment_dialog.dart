import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../data/models/payment_model.dart';
import '../../providers/payments_provider.dart';

class RegisterPaymentDialog extends ConsumerStatefulWidget {
  const RegisterPaymentDialog({
    super.key,
    required this.patientId,
    required this.saldoPendiente,
  });

  final String patientId;
  final double saldoPendiente;

  @override
  ConsumerState<RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends ConsumerState<RegisterPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  final _referenciaController = TextEditingController();
  final _notasController = TextEditingController();

  PaymentMethod _metodo = PaymentMethod.efectivo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _referenciaController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    final saldaDeuda = monto != null && monto == widget.saldoPendiente;

    return AlertDialog(
      title: const Text('Registrar pago'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                ),
                validator: _validateMonto,
                onChanged: (_) => setState(() {}),
              ),
              if (saldaDeuda) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OcgColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Este pago saldará la deuda completa del paciente.',
                    style: TextStyle(
                      color: OcgColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                value: _metodo,
                items: const [
                  DropdownMenuItem(
                    value: PaymentMethod.efectivo,
                    child: Text('Efectivo'),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.transferencia,
                    child: Text('Transferencia bancaria'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _metodo = value);
                      },
                decoration: const InputDecoration(labelText: 'Método de pago'),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _metodo == PaymentMethod.transferencia
                    ? TextFormField(
                        key: const ValueKey('referencia-field'),
                        controller: _referenciaController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Referencia bancaria',
                          helperText: 'Número de comprobante o referencia',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              TextFormField(
                controller: _notasController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Notas internas (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OcgColors.espresso,
            foregroundColor: OcgColors.ivory,
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: OcgColors.ivory),
                )
              : const Text('Registrar pago'),
        ),
      ],
    );
  }

  String? _validateMonto(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Ingresa el monto';

    final monto = double.tryParse(raw.replaceAll(',', '.'));
    if (monto == null || monto <= 0) return 'El monto debe ser mayor a cero';
    if (monto > widget.saldoPendiente) {
      return 'El monto no puede superar el saldo pendiente';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authStateProvider).asData?.value;
    final adminId = user?.uid ?? '';
    if (adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al administrador actual.')),
      );
      return;
    }

    final monto = double.parse(_montoController.text.trim().replaceAll(',', '.'));

    setState(() => _saving = true);

    await ref.read(registerPaymentProvider.notifier).registerManual(
          patientId: widget.patientId,
          monto: monto,
          metodo: _metodo,
          adminId: adminId,
          referencia: _referenciaController.text.trim().isEmpty
              ? null
              : _referenciaController.text.trim(),
          notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        );

    final result = ref.read(registerPaymentProvider);

    if (!mounted) return;

    if (result.hasError) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error.toString())),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pago registrado correctamente.'),
        backgroundColor: OcgColors.success,
      ),
    );
  }
}
