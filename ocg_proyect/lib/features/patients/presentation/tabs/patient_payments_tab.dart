import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/payments/presentation/widgets/payment_summary_card.dart';
import '../../../../features/payments/presentation/widgets/register_payment_dialog.dart';
import '../../../../features/payments/presentation/widgets/transaction_list.dart';
import '../../../../features/payments/providers/payments_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';

class PatientPaymentsTab extends ConsumerWidget {
  const PatientPaymentsTab({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(patientPaymentProvider(patientId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaymentSummaryCard(patientId: patientId, isAdmin: true),
          const SizedBox(height: 16),
          paymentAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (payment) => Row(
              children: [
                const Expanded(
                  child: Text(
                    'Próximo pago',
                    style: TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _pickDate(context, ref),
                  child: Text(
                    DateFormat(
                      'dd/MM/yyyy',
                    ).format(payment?.fechaProximoPago ?? DateTime.now()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          paymentAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text(
              'No se pudo cargar pagos: $error',
              style: const TextStyle(color: OcgColors.error),
            ),
            data: (payment) {
              final saldoPendiente = payment?.saldoPendiente ?? 0;

              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: payment == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => RegisterPaymentDialog(
                          patientId: patientId,
                          saldoPendiente: saldoPendiente,
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Registrar pago'),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Historial de transacciones',
            style: TextStyle(
              color: OcgColors.espresso,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TransactionList(patientId: patientId),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked == null) return;

    await ref
        .read(paymentsRepositoryProvider)
        .updateNextPaymentDate(patientId, picked);
  }
}
