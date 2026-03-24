import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../patient/presentation/web/shell/patient_web_shell.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/payment_model.dart';
import '../providers/payments_provider.dart';
import 'widgets/payment_summary_card.dart';
import 'widgets/transaction_list.dart';

class PatientPaymentsScreen extends ConsumerStatefulWidget {
  const PatientPaymentsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<PatientPaymentsScreen> createState() => _PatientPaymentsScreenState();
}

class _PatientPaymentsScreenState extends ConsumerState<PatientPaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(initiatePayuPaymentProvider, (previous, next) {
      if (!mounted) return;
      next.whenOrNull(
        data: (url) {
          if (url == null || url.isEmpty) return;
          context.push('${RouteNames.patientPayuCheckout}?checkoutUrl=${Uri.encodeComponent(url)}');
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        },
      );
    });

    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus pagos.')),
      );
    }

    final paymentAsync = ref.watch(patientPaymentProvider(user.uid));

    final content = SingleChildScrollView(
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
              if (payment == null) {
                return const Text(
                  'No existe resumen financiero para este paciente.',
                  style: TextStyle(color: OcgColors.error),
                );
              }

              final saldo = payment.saldoPendiente;
              if (saldo <= 0 && payment.estado == PaymentStatus.pagadoTotal) {
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
                onPressed: () => _confirmAndPayu(
                  context,
                  user.uid,
                  saldo,
                  user.email ?? '',
                  user.displayName ?? 'Paciente',
                ),
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
    );

    if (widget.embedded) return content;

    if (WebLayoutContext.useDesktopShell(context)) {
      return PatientWebShell(
        currentRoute: RouteNames.patientPayments,
        title: 'Mis pagos',
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: content,
    );
  }

  Future<void> _confirmAndPayu(
    BuildContext context,
    String patientId,
    double monto,
    String patientEmail,
    String patientName,
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

    await ref.read(initiatePayuPaymentProvider.notifier).initiate(
          patientId: patientId,
          monto: monto,
          patientEmail: patientEmail,
          patientName: patientName,
        );
  }
}
