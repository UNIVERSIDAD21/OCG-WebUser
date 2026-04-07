import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/payment_model.dart';
import '../providers/payments_provider.dart';

class PatientPaymentsScreen extends ConsumerStatefulWidget {
  const PatientPaymentsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
  });

  final bool embedded;
  final String? patientIdOverride;

  @override
  ConsumerState<PatientPaymentsScreen> createState() => _PatientPaymentsScreenState();
}

class _PatientPaymentsScreenState extends ConsumerState<PatientPaymentsScreen> {
  _PaymentsFilter _filter = _PaymentsFilter.todos;

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
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');
    if (effectivePatientId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus pagos.')),
      );
    }

    final paymentAsync = ref.watch(patientPaymentProvider(effectivePatientId));
    final txAsync = ref.watch(patientTransactionsProvider(effectivePatientId));
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              14,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [OcgColors.espresso, OcgColors.bronze],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mis pagos',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Estado de cuenta y movimientos',
                  style: TextStyle(
                    color: Color(0xCCF8F5F0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                paymentAsync.when(
                  loading: () => const _LoadingCard(),
                  error: (error, _) => _ErrorCard(message: 'No se pudo cargar pagos: $error'),
                  data: (payment) {
                    if (payment == null) {
                      return const _ErrorCard(message: 'No existe resumen financiero para este paciente.');
                    }

                    final total = payment.totalTratamiento;
                    final saldo = payment.saldoPendiente;
                    final pagado = (total > 0) ? (total - saldo).clamp(0, total) : payment.montoPagado;
                    final progress = (total > 0) ? ((pagado / total) * 100).round().clamp(0, 100) : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FinancialSummaryCard(
                          total: total,
                          pagado: pagado.toDouble(),
                          pendiente: saldo,
                          progressPercent: progress,
                          currency: currency,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OcgColors.espresso,
                              foregroundColor: OcgColors.ivory,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: saldo > 0
                                ? () => _confirmAndPayu(
                                      context,
                                      effectivePatientId,
                                      saldo,
                                      user.email ?? '',
                                      user.displayName ?? 'Paciente',
                                    )
                                : null,
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: Text(saldo > 0 ? 'Pagar con PayU' : 'Tratamiento pagado'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NextPaymentCard(
                          fechaProximoPago: payment.fechaProximoPago,
                          saldoPendiente: saldo,
                          currency: currency,
                          onGoToPay: saldo > 0
                              ? () => _confirmAndPayu(
                                    context,
                                    effectivePatientId,
                                    saldo,
                                    user.email ?? '',
                                    user.displayName ?? 'Paciente',
                                  )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Historial de pagos',
                  style: TextStyle(
                    color: Color(0xFF1A1410),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _FilterRow(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 10),
                txAsync.when(
                  loading: () => const _LoadingCard(),
                  error: (error, _) => _ErrorCard(message: 'No se pudo cargar transacciones: $error'),
                  data: (transactions) {
                    final payment = paymentAsync.asData?.value;
                    final hasPending = (payment?.saldoPendiente ?? 0) > 0;

                    final filtered = switch (_filter) {
                      _PaymentsFilter.todos => transactions,
                      _PaymentsFilter.pagados => transactions,
                      _PaymentsFilter.pendientes => const <PaymentTransaction>[],
                    };

                    if (_filter == _PaymentsFilter.pendientes) {
                      if (!hasPending) {
                        return const _EmptyCard(message: 'No tienes pendientes por pagar.');
                      }
                      return _PendingCard(
                        saldoPendiente: payment!.saldoPendiente,
                        fechaProximoPago: payment.fechaProximoPago,
                        currency: currency,
                      );
                    }

                    if (filtered.isEmpty) {
                      return const _EmptyCard(message: 'No hay pagos registrados todavía.');
                    }

                    return Column(
                      children: filtered
                          .map((tx) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _TransactionCard(tx: tx, currency: currency),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

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
        content: Text('¿Deseas continuar con el pago por ${monto.toStringAsFixed(0)} COP?'),
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

enum _PaymentsFilter { todos, pagados, pendientes }

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECD9C6)),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD2D2)),
        ),
        child: Text(message, style: const TextStyle(color: OcgColors.error)),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECD9C6)),
        ),
        child: Text(message, style: const TextStyle(color: Color(0xFF8A6F59))),
      );
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.total,
    required this.pagado,
    required this.pendiente,
    required this.progressPercent,
    required this.currency,
  });

  final double total;
  final double pagado;
  final double pendiente;
  final int? progressPercent;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECD9C6)),
        boxShadow: const [
          BoxShadow(color: Color(0x122C2016), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen financiero',
            style: TextStyle(color: Color(0xFF1A1410), fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _money('Total tratamiento', currency.format(total))),
              const SizedBox(width: 6),
              Expanded(child: _money('Pagado', currency.format(pagado), valueColor: const Color(0xFF166534))),
              const SizedBox(width: 6),
              Expanded(child: _money('Pendiente', currency.format(pendiente), valueColor: const Color(0xFF92400E))),
            ],
          ),
          const SizedBox(height: 10),
          if (progressPercent != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Avance de pago', style: TextStyle(fontSize: 11, color: Color(0xFF8A6F59))),
                Text('$progressPercent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progressPercent! / 100,
                backgroundColor: const Color(0xFFF2EDE8),
                valueColor: const AlwaysStoppedAnimation<Color>(OcgColors.espresso),
              ),
            ),
          ] else ...[
            const Text(
              'Sin base suficiente para calcular porcentaje.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8A6F59)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _money(String label, String value, {Color valueColor = const Color(0xFF1A1410)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A6F59), fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({
    required this.fechaProximoPago,
    required this.saldoPendiente,
    required this.currency,
    this.onGoToPay,
  });

  final DateTime? fechaProximoPago;
  final double saldoPendiente;
  final NumberFormat currency;
  final VoidCallback? onGoToPay;

  @override
  Widget build(BuildContext context) {
    final dateLabel = fechaProximoPago == null
        ? 'Sin fecha programada'
        : DateFormat("dd MMM yyyy", 'es_CO').format(fechaProximoPago!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECD9C6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2EDE8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today, size: 17, color: OcgColors.espresso),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próximo pago', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1410))),
                const SizedBox(height: 2),
                Text(dateLabel, style: const TextStyle(color: Color(0xFF8A6F59), fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('Saldo actual: ${currency.format(saldoPendiente)}', style: const TextStyle(color: Color(0xFF8A6F59), fontSize: 12)),
              ],
            ),
          ),
          if (onGoToPay != null)
            TextButton(onPressed: onGoToPay, child: const Text('Pagar')),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _PaymentsFilter selected;
  final ValueChanged<_PaymentsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(_PaymentsFilter v, String label) {
      final active = selected == v;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(v),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? OcgColors.espresso : const Color(0xFFF2EDE8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_PaymentsFilter.todos, 'Todos'),
        const SizedBox(width: 6),
        chip(_PaymentsFilter.pagados, 'Pagados'),
        const SizedBox(width: 6),
        chip(_PaymentsFilter.pendientes, 'Pendientes'),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.saldoPendiente, required this.fechaProximoPago, required this.currency});

  final double saldoPendiente;
  final DateTime? fechaProximoPago;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final fecha = fechaProximoPago == null
        ? 'Sin fecha programada'
        : DateFormat("dd/MM/yyyy", 'es_CO').format(fechaProximoPago!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5CC9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pago pendiente', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Vencimiento: $fecha', style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F59))),
              ],
            ),
          ),
          Text(currency.format(saldoPendiente), style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.tx, required this.currency});

  final PaymentTransaction tx;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final statusLabel = 'Pagado';
    final statusColor = const Color(0xFF166534);
    final dateFmt = DateFormat("dd MMM yyyy", 'es_CO');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECD9C6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, size: 18, color: Color(0xFF166534)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_methodLabel(tx.metodo), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1410))),
                const SizedBox(height: 2),
                Text(dateFmt.format(tx.fecha), style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F59))),
                if ((tx.referencia ?? '').trim().isNotEmpty)
                  Text('Ref: ${tx.referencia}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6F59))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(tx.monto), style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel, style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.efectivo => 'Efectivo',
        PaymentMethod.transferencia => 'Transferencia',
        PaymentMethod.payu => 'PayU',
      };
}
