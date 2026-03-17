import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_card.dart';
import '../../../../shared/widgets/ocg_chip.dart';
import '../../../../shared/widgets/ocg_loading_screen.dart';
import '../../data/models/payment_model.dart';
import '../../providers/payments_provider.dart';

class PaymentSummaryCard extends ConsumerWidget {
  const PaymentSummaryCard({
    super.key,
    required this.patientId,
    this.isAdmin = false,
  });

  final String patientId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPayment = ref.watch(patientPaymentProvider(patientId));

    return OcgCard(
      child: asyncPayment.when(
        loading: () => const SizedBox(
          height: 120,
          child: ClipRect(child: OcgLoadingScreen()),
        ),
        error: (error, _) => Text(
          'Error cargando resumen de pagos: $error',
          style: const TextStyle(color: OcgColors.error, fontWeight: FontWeight.w600),
        ),
        data: (payment) {
          if (payment == null) {
            return const Text(
              'No existe resumen financiero para este paciente.',
              style: TextStyle(color: OcgColors.error),
            );
          }

          final currency = NumberFormat.currency(
            locale: 'es_CO',
            symbol: r'$',
            decimalDigits: 0,
          );

          final saldoColor = payment.saldoPendiente > 0 ? OcgColors.bronze : OcgColors.success;
          final statusStyle = _statusStyle(payment.estado);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin ? 'Resumen financiero del paciente' : 'Resumen financiero',
                style: const TextStyle(
                  color: OcgColors.espresso,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _row('Total tratamiento', currency.format(payment.totalTratamiento), OcgColors.ink),
              _row('Pagado', currency.format(payment.montoPagado), OcgColors.ink),
              _row('Saldo pendiente', currency.format(payment.saldoPendiente), saldoColor),
              const SizedBox(height: 8),
              OcgChip(
                label: _statusLabel(payment.estado),
                backgroundColor: statusStyle.$1,
                textColor: statusStyle.$2,
              ),
              const SizedBox(height: 8),
              Text(
                payment.fechaProximoPago == null
                    ? 'Próximo pago: No definido'
                    : 'Próximo pago: ${DateFormat("dd MMM yyyy", 'es_CO').format(payment.fechaProximoPago!)}',
                style: const TextStyle(color: OcgColors.ink),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: OcgColors.ink))),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _statusLabel(PaymentStatus status) => switch (status) {
        PaymentStatus.alDia => 'Al día',
        PaymentStatus.pendiente => 'Pendiente',
        PaymentStatus.vencido => 'Vencido',
        PaymentStatus.pagadoTotal => 'Pagado total',
      };

  (Color, Color) _statusStyle(PaymentStatus status) => switch (status) {
        PaymentStatus.alDia => (OcgColors.success.withValues(alpha: 0.14), OcgColors.success),
        PaymentStatus.pendiente => (OcgColors.bronze.withValues(alpha: 0.18), OcgColors.bronze),
        PaymentStatus.vencido => (OcgColors.error.withValues(alpha: 0.16), OcgColors.error),
        PaymentStatus.pagadoTotal => (OcgColors.espresso.withValues(alpha: 0.12), OcgColors.espresso),
      };
}
