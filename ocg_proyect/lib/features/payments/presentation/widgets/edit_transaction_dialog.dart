import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../providers/payments_provider.dart';

class EditTransactionDialog extends ConsumerStatefulWidget {
  const EditTransactionDialog({
    super.key,
    required this.patientId,
    required this.transactionId,
    required this.treatmentId,
    required this.currentMonto,
  });

  final String patientId;
  final String transactionId;
  final String treatmentId;
  final double currentMonto;

  @override
  ConsumerState<EditTransactionDialog> createState() =>
      _EditTransactionDialogState();
}

class _EditTransactionDialogState extends ConsumerState<EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  final _notasController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController(
      text: _formatDoubleToText(widget.currentMonto),
    );
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentAsync = ref.watch(
      treatmentPaymentProvider((
        patientId: widget.patientId,
        treatmentId: widget.treatmentId,
      )),
    );

    return paymentAsync.when(
      loading: () => const AlertDialog(
        content: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AlertDialog(
        title: const Text('Error'),
        content: Text('No se pudo cargar la información del pago: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
      data: (payment) {
        final totalTratamiento = (payment?.totalTratamiento ?? 0).toDouble();
        final saldoPendiente = (payment?.saldoPendiente ?? 0).toDouble();
        return _buildDialogContent(totalTratamiento, saldoPendiente);
      },
    );
  }

  Widget _buildDialogContent(double totalTratamiento, double saldoPendiente) {
    final nuevoMonto = _parseMonto(_montoController.text);
    final delta = nuevoMonto != null ? nuevoMonto - widget.currentMonto : 0;
    final nuevoSaldoEstimado = saldoPendiente - delta;

    return AlertDialog(
      title: const Text('Editar monto de pago'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2D0BC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto actual: \$${_formatCop(widget.currentMonto)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E5644),
                        fontSize: 13,
                      ),
                    ),
                    if (nuevoMonto != null && nuevoMonto != widget.currentMonto) ...[
                      const SizedBox(height: 4),
                      Text(
                        delta > 0
                            ? 'Se reducirá el saldo pendiente en \$${_formatCop(delta.abs().toDouble())}'
                            : 'Se aumentará el saldo pendiente en \$${_formatCop(delta.abs().toDouble())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: delta > 0
                              ? OcgColors.success
                              : OcgColors.warning,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nuevo saldo estimado: \$${_formatCop(nuevoSaldoEstimado.clamp(0, double.infinity).toDouble())}',
                        style: const TextStyle(
                          color: Color(0xFF6E5644),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nuevo monto',
                  prefixText: r'$ ',
                  hintText: 'Ej: 250.000',
                ),
                validator: (v) => _validateMonto(v, totalTratamiento),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notasController,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Nota del cambio (opcional)',
                  helperText: 'Explica brevemente el motivo del ajuste',
                ),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OcgColors.ivory,
                  ),
                )
              : const Text('Guardar cambio'),
        ),
      ],
    );
  }

  String? _validateMonto(String? value, double totalTratamiento) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Ingresa el monto';

    final monto = _parseMonto(raw);
    if (monto == null || monto <= 0) return 'El monto debe ser mayor a cero';
    if (monto > totalTratamiento) {
      return 'El monto no puede superar el total del tratamiento';
    }
    return null;
  }

  static String _formatDoubleToText(double value) {
    final digits = value.toStringAsFixed(0);
    return CurrencyInputFormatter.formatDigits(digits);
  }

  double? _parseMonto(String raw) {
    return CurrencyInputFormatter.parseToDouble(raw);
  }

  String _formatCop(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nuevoMonto = _parseMonto(_montoController.text);
    if (nuevoMonto == null) return;

    // Si el monto no cambió, cerrar sin hacer nada
    if (nuevoMonto == widget.currentMonto) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    try {
      await ref
          .read(registerPaymentProvider.notifier)
          .editTransactionAmount(
            patientId: widget.patientId,
            transactionId: widget.transactionId,
            nuevoMonto: nuevoMonto,
            treatmentId: widget.treatmentId,
            notas: _notasController.text.trim().isEmpty
                ? null
                : _notasController.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monto del pago actualizado correctamente.'),
          backgroundColor: OcgColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al editar: $e')),
      );
    }
  }
}
