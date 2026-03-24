import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';
import 'summary_card.dart';

class PaymentSummaryPanel extends StatelessWidget {
  const PaymentSummaryPanel({
    super.key,
    required this.total,
    required this.pending,
    required this.paid,
  });

  final double total;
  final double pending;
  final double paid;

  String _fmt(num value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 860;

        if (stacked) {
          return Column(
            children: [
              SummaryCard(title: 'Total', value: '\$${_fmt(total)} COP', icon: Icons.payments_outlined),
              const SizedBox(height: 10),
              SummaryCard(title: 'Pagado', value: '\$${_fmt(paid)} COP', icon: Icons.check_circle_outline),
              const SizedBox(height: 10),
              SummaryCard(title: 'Pendiente', value: '\$${_fmt(pending)} COP', icon: Icons.warning_amber_outlined),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: SummaryCard(title: 'Total', value: '\$${_fmt(total)} COP', icon: Icons.payments_outlined)),
            const SizedBox(width: 10),
            Expanded(child: SummaryCard(title: 'Pagado', value: '\$${_fmt(paid)} COP', icon: Icons.check_circle_outline)),
            const SizedBox(width: 10),
            Expanded(child: SummaryCard(title: 'Pendiente', value: '\$${_fmt(pending)} COP', icon: Icons.warning_amber_outlined)),
          ],
        );
      },
    );
  }
}
