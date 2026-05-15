import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_skeleton.dart';
import '../../data/models/payment_model.dart';
import '../../providers/payments_provider.dart';

class TransactionList extends ConsumerWidget {
  const TransactionList({super.key, required this.patientId, this.treatmentId});

  final String patientId;
  final String? treatmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(
      patientTransactionsProvider((
        patientId: patientId,
        treatmentId: treatmentId,
      )),
    );
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final dateFmt = _safeDateFormat();

    return asyncTx.when(
      loading: () => const OcgSkeletonList(
        items: 2,
        cardHeight: 128,
        padding: EdgeInsets.zero,
      ),
      error: (error, _) => Text(
        'Error cargando transacciones: $error',
        style: const TextStyle(
          color: OcgColors.error,
          fontWeight: FontWeight.w600,
        ),
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
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBF8), Color(0xFFF7EFE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8D8C8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x122C2016),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E5D8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _methodIcon(tx.metodo),
                          color: OcgColors.espresso,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _methodLabel(tx.metodo),
                              style: const TextStyle(
                                color: OcgColors.espresso,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFmt.format(tx.fecha),
                              style: const TextStyle(
                                color: Color(0xFF6E5644),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(tx.monto),
                            style: const TextStyle(
                              color: OcgColors.bronze,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if ((tx.reciboUrl ?? '').isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  _openReceipt(context, tx.reciboUrl!),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ver recibo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((tx.referencia ?? '').isNotEmpty)
                        _TxInfoChip(label: 'Ref: ${tx.referencia}'),
                      _TxInfoChip(
                        label: _registeredByInlineLabel(tx.registradoPor),
                      ),
                    ],
                  ),
                  if ((tx.notas ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F3EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tx.notas!.trim(),
                        style: const TextStyle(
                          color: Color(0xFF6E5644),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  DateFormat _safeDateFormat() {
    try {
      return DateFormat("d 'de' MMM yyyy, hh:mm a", 'es_CO');
    } catch (_) {
      return DateFormat('yyyy-MM-dd HH:mm');
    }
  }

  String _methodLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.efectivo => 'Efectivo',
    PaymentMethod.transferencia => 'Transferencia',
    PaymentMethod.epayco => 'Epayco',
  };

  IconData _methodIcon(PaymentMethod method) => switch (method) {
    PaymentMethod.efectivo => Icons.payments_outlined,
    PaymentMethod.transferencia => Icons.account_balance_outlined,
    PaymentMethod.epayco => Icons.credit_card_outlined,
  };

  String _registeredByInlineLabel(String registradoPor) {
    final value = registradoPor.trim();
    if (value.isEmpty) return 'Registrado por: Administrador';
    if (value == 'epayco_webhook') return 'Registrado por: Epayco';
    if (value == 'admin') return 'Registrado por: Administrador';
    if (value.length >= 20) return 'Registrado por: Administrador';
    return 'Registrado por: $value';
  }

  Future<void> _openReceipt(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL de recibo inválida.')));
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

class _TxInfoChip extends StatelessWidget {
  const _TxInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8DC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OcgColors.espresso,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
