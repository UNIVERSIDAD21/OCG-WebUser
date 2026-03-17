import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/payments_provider.dart';
import 'widgets/payment_summary_card.dart';
import 'widgets/transaction_list.dart';

class PatientPaymentsScreen extends ConsumerWidget {
  const PatientPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus pagos.')),
      );
    }

    final paymentAsync = ref.watch(patientPaymentProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaymentSummaryCard(patientId: user.uid, isAdmin: false),
            const SizedBox(height: 16),
            paymentAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(
                'No se pudo cargar pagos: $error',
                style: const TextStyle(color: OcgColors.error),
              ),
              data: (payment) {
                final saldo = payment?.saldoPendiente ?? 0;
                if (saldo <= 0) {
                  return OcgChip(
                    label: 'Tratamiento pagado en su totalidad',
                    backgroundColor: OcgColors.success.withValues(alpha: 0.14),
                    textColor: OcgColors.success,
                  );
                }

                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OcgColors.espresso,
                    foregroundColor: OcgColors.ivory,
                  ),
                  onPressed: () => _confirmAndPayu(context, ref, user.uid, saldo),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Pagar con PayU'),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Historial de pagos',
              style: TextStyle(
                color: OcgColors.espresso,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TransactionList(patientId: user.uid),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndPayu(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    double monto,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text('¿Deseas continuar con el pago por \$${monto.toStringAsFixed(0)} COP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final url = await ref.read(initiatePayuPaymentProvider.notifier).initiate(
            patientId: patientId,
            monto: monto,
          );

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PayuCheckoutScreen(url: url)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class PayuCheckoutScreen extends StatelessWidget {
  const PayuCheckoutScreen({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout PayU')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(url),
      ),
    );
  }
}
