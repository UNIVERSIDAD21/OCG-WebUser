import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_loading_screen.dart';
import '../../data/models/payment_model.dart';
import '../../providers/payments_provider.dart';

class TransactionList extends ConsumerWidget {
  const TransactionList({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(patientTransactionsProvider(patientId));
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    final dateFmt = DateFormat("d 'de' MMM yyyy, hh:mm a", 'es_CO');

    return asyncTx.when(
      loading: () => const SizedBox(height: 120, child: ClipRect(child: OcgLoadingScreen())),
      error: (error, _) => Text(
        'Error cargando transacciones: $error',
        style: const TextStyle(color: OcgColors.error, fontWeight: FontWeight.w600),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const OcgEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Sin pagos registrados todavía.',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (_, __) => Divider(color: OcgColors.sand.withValues(alpha: 0.8)),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _methodLabel(tx.metodo),
                style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFmt.format(tx.fecha),
                    style: const TextStyle(color: OcgColors.ink),
                  ),
                  if ((tx.referencia ?? '').isNotEmpty)
                    Text('Ref: ${tx.referencia}', style: const TextStyle(color: OcgColors.ink)),
                  Text('Registrado por: ${tx.registradoPor}', style: const TextStyle(color: OcgColors.ink)),
                  if ((tx.notas ?? '').trim().isNotEmpty)
                    Text(
                      'Notas: ${tx.notas!.trim()}',
                      style: const TextStyle(color: OcgColors.ink),
                    ),
                ],
              ),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.format(tx.monto),
                    style: const TextStyle(color: OcgColors.bronze, fontWeight: FontWeight.w700),
                  ),
                  if ((tx.reciboUrl ?? '').isNotEmpty)
                    TextButton(
                      onPressed: () => _openReceipt(context, tx.reciboUrl!),
                      child: const Text('Ver recibo'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.efectivo => 'Efectivo',
        PaymentMethod.transferencia => 'Transferencia',
        PaymentMethod.payu => 'PayU',
      };

  Future<void> _openReceipt(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de recibo inválida.')),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el recibo.')),
      );
    }
  }
}
