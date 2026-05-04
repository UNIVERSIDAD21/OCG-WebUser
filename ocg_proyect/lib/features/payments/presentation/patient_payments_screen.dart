import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/currency_input_formatter.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_data_resolution.dart';
import '../../patients/presentation/patient_viewer_mode.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../data/models/financial_item_model.dart';
import '../data/models/payment_model.dart';
import '../providers/payments_provider.dart';
import '../providers/treatment_financial_provider.dart';
import 'widgets/transaction_list.dart';

class PatientPaymentsScreen extends ConsumerStatefulWidget {
  const PatientPaymentsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
    this.viewerMode = PatientViewerMode.patient,
  });

  final bool embedded;
  final String? patientIdOverride;
  final PatientViewerMode viewerMode;

  @override
  ConsumerState<PatientPaymentsScreen> createState() =>
      _PatientPaymentsScreenState();
}

class _PatientPaymentsScreenState extends ConsumerState<PatientPaymentsScreen> {
  _PaymentsFilter _filter = _PaymentsFilter.todos;
  String? _selectedTreatmentId;
  final Set<String> _ensuredTreatmentAccounts = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(initiatePayuPaymentProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      next.whenOrNull(
        data: (url) {
          if (url == null || url.isEmpty) return;
          context.push(
            '${RouteNames.patientPayuCheckout}?checkoutUrl=${Uri.encodeComponent(url)}',
          );
        },
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    final user = ref.watch(authStateProvider).asData?.value;
    final isAdminViewer = widget.viewerMode == PatientViewerMode.adminViewer;
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');
    if (effectivePatientId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus pagos.')),
      );
    }

    if (!isAdminViewer) {
      return _buildPatientTreatmentAwareView(
        context,
        effectivePatientId,
        user?.email ?? '',
        user?.displayName ?? 'Paciente',
      );
    }

    final paymentAsync = ref.watch(patientPaymentProvider(effectivePatientId));
    final txAsync = ref.watch(
      patientTransactionsProvider((
        patientId: effectivePatientId,
        treatmentId: null,
      )),
    );
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdminViewer ? 'Pagos del paciente' : 'Mis pagos',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isAdminViewer
                      ? 'Gestión financiera y movimientos'
                      : 'Estado de cuenta y movimientos',
                  style: TextStyle(color: Color(0xCCF8F5F0), fontSize: 13),
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
                  error: (error, _) =>
                      _ErrorCard(message: 'No se pudo cargar pagos: $error'),
                  data: (payment) {
                    if (payment == null) {
                      return const _ErrorCard(
                        message:
                            'No existe resumen financiero para este paciente.',
                      );
                    }

                    final total = payment.totalTratamiento;
                    final saldo = payment.saldoPendiente;
                    final pagado = (total > 0)
                        ? (total - saldo).clamp(0, total)
                        : payment.montoPagado;
                    final progress = (total > 0)
                        ? ((pagado / total) * 100).round().clamp(0, 100)
                        : null;

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
                                ? () => isAdminViewer
                                      ? _showRegisterManualPaymentDialog(
                                          context,
                                          effectivePatientId,
                                          saldo,
                                        )
                                      : _confirmAndPayu(
                                          context,
                                          effectivePatientId,
                                          '',
                                          saldo,
                                          user?.email ?? '',
                                          user?.displayName ?? 'Paciente',
                                        )
                                : null,
                            icon: Icon(
                              isAdminViewer
                                  ? Icons.add_card_outlined
                                  : Icons.lock_outline,
                              size: 18,
                            ),
                            label: Text(
                              saldo > 0
                                  ? isAdminViewer
                                        ? 'Registrar pago'
                                        : 'Pagar con PayU'
                                  : 'Tratamiento pagado',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NextPaymentCard(
                          fechaProximoPago: payment.fechaProximoPago,
                          saldoPendiente: saldo,
                          currency: currency,
                          onGoToPay: saldo > 0
                              ? () => isAdminViewer
                                    ? _showRegisterManualPaymentDialog(
                                        context,
                                        effectivePatientId,
                                        saldo,
                                      )
                                    : _confirmAndPayu(
                                        context,
                                        effectivePatientId,
                                        '',
                                        saldo,
                                        user?.email ?? '',
                                        user?.displayName ?? 'Paciente',
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
                  error: (error, _) => _ErrorCard(
                    message: 'No se pudo cargar transacciones: $error',
                  ),
                  data: (transactions) {
                    final payment = paymentAsync.asData?.value;
                    final hasPending = (payment?.saldoPendiente ?? 0) > 0;

                    final filtered = switch (_filter) {
                      _PaymentsFilter.todos => transactions,
                      _PaymentsFilter.pagados => transactions,
                      _PaymentsFilter.pendientes =>
                        const <PaymentTransaction>[],
                    };

                    if (_filter == _PaymentsFilter.pendientes) {
                      if (!hasPending) {
                        return const _EmptyCard(
                          message: 'No tienes pendientes por pagar.',
                        );
                      }
                      return _PendingCard(
                        saldoPendiente: payment!.saldoPendiente,
                        fechaProximoPago: payment.fechaProximoPago,
                        currency: currency,
                      );
                    }

                    if (filtered.isEmpty) {
                      return const _EmptyCard(
                        message: 'No hay pagos registrados todavía.',
                      );
                    }

                    return Column(
                      children: filtered
                          .map(
                            (tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TransactionCard(
                                tx: tx,
                                currency: currency,
                              ),
                            ),
                          )
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
      appBar: AppBar(
        title: Text(isAdminViewer ? 'Pagos del paciente' : 'Mis pagos'),
      ),
      body: content,
    );
  }

  Widget _buildPatientTreatmentAwareView(
    BuildContext context,
    String patientId,
    String patientEmail,
    String patientName,
  ) {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final patientAsync = ref.watch(patientByIdProvider(patientId));

    return patientAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('No se pudo cargar pagos: $error')),
      ),
      data: (patient) {
        if (patient == null) {
          return const Scaffold(
            body: Center(child: Text('Paciente no encontrado.')),
          );
        }

        final resolution = ref.watch(
          effectivePatientPaymentsProvider((
            patientId: patientId,
            patient: patient,
          )),
        );
        final treatments = resolution.treatments;
        for (final treatment in treatments.where(
          (item) => !item.id.startsWith('legacy-primary-'),
        )) {
          if (_ensuredTreatmentAccounts.add(treatment.id)) {
            Future.microtask(
              () => ref.read(ensureTreatmentPaymentAccountProvider)(
                patientId,
                treatment,
              ),
            );
          }
        }
        if (treatments.isEmpty) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: OcgEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Aún no tienes pagos asociados',
                  subtitle:
                      'Cuando la clínica cree tu primer tratamiento podrás ver aquí su cuenta.',
                ),
              ),
            ),
          );
        }

        final selectedTreatment = _resolveSelectedTreatment(treatments);
        final selectedAccount = resolution.paymentAccounts
            .cast<EffectivePatientPaymentAccount?>()
            .firstWhere(
              (item) => item?.treatmentId == selectedTreatment.id,
              orElse: () => null,
            );
        final financialItemsAsync = ref.watch(
          treatmentFinancialItemsProvider((
            patientId: patientId,
            treatmentId: selectedTreatment.id,
          )),
        );

        final compact = MediaQuery.sizeOf(context).width < 380;

        final content = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  MediaQuery.paddingOf(context).top + 18,
                  compact ? 16 : 20,
                  compact ? 14 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      OcgColors.espresso,
                      OcgColors.bronze,
                      Color(0xFFB89A84),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A2C2016),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos',
                      style: TextStyle(
                        color: OcgColors.ivory,
                        fontSize: compact ? 25 : 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta el estado de tus tratamientos',
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.82),
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: OcgColors.ivory.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: OcgColors.ivory.withOpacity(0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _PatientHeaderChip(
                                label: '${treatments.length} tratamientos',
                              ),
                              _PatientHeaderChip(
                                label:
                                    '${treatments.where((t) => !t.isFinished).length} activos',
                              ),
                              _PatientHeaderChip(
                                label:
                                    selectedAccount?.payment.fechaProximoPago ==
                                        null
                                    ? 'Sin próxima cuota'
                                    : 'Próximo pago ${_formatCompactDate(selectedAccount!.payment.fechaProximoPago!)}',
                              ),
                            ],
                          ),
                          if (treatments.length > 1) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Selecciona un tratamiento',
                              style: TextStyle(
                                color: OcgColors.ivory,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: compact ? 112 : 122,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: treatments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final treatment = treatments[index];
                                  final account = resolution.paymentAccounts
                                      .cast<EffectivePatientPaymentAccount?>()
                                      .firstWhere(
                                        (item) =>
                                            item?.treatmentId == treatment.id,
                                        orElse: () => null,
                                      );
                                  return _PatientPaymentTreatmentCard(
                                    treatment: treatment,
                                    selected:
                                        treatment.id == selectedTreatment.id,
                                    account: account?.payment,
                                    onTap: () => setState(
                                      () => _selectedTreatmentId = treatment.id,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  18,
                  compact ? 16 : 20,
                  110,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PatientPaymentSummaryCard(
                      treatment: selectedTreatment,
                      payment: selectedAccount?.payment,
                      currency: currency,
                    ),
                    const SizedBox(height: 16),
                    financialItemsAsync.when(
                      loading: () => const _LoadingCard(),
                      error: (error, _) => _ErrorCard(
                        message: 'No se pudieron cargar conceptos: $error',
                      ),
                      data: (items) => _PatientFinancialBreakdownCard(
                        items: items,
                        currency: currency,
                      ),
                    ),
                    if ((selectedAccount?.payment.saldoPendiente ?? 0) > 0) ...[
                      const SizedBox(height: 16),
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
                          ),
                          onPressed: () => _confirmAndPayu(
                            context,
                            patientId,
                            selectedTreatment.id,
                            selectedAccount!.payment.saldoPendiente,
                            patientEmail,
                            patientName,
                          ),
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: Text(
                            'Pagar ${selectedTreatment.displayName} con PayU',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Historial de ${selectedTreatment.displayName}',
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TransactionList(
                      patientId: patientId,
                      treatmentId: selectedTreatment.id,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (widget.embedded) return content;
        return Scaffold(body: content);
      },
    );
  }

  PatientTreatment _resolveSelectedTreatment(
    List<PatientTreatment> treatments,
  ) {
    if (_selectedTreatmentId != null) {
      for (final treatment in treatments) {
        if (treatment.id == _selectedTreatmentId) return treatment;
      }
    }
    for (final treatment in treatments) {
      if (treatment.isPrimary) return treatment;
    }
    for (final treatment in treatments) {
      if (!treatment.isFinished) return treatment;
    }
    return treatments.first;
  }

  String _formatCompactDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _showRegisterManualPaymentDialog(
    BuildContext context,
    String patientId,
    double suggestedAmount,
  ) async {
    final amountCtrl = TextEditingController(
      text: CurrencyInputFormatter.formatDigits(
        suggestedAmount.toStringAsFixed(0),
      ),
    );
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar pago manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: const InputDecoration(labelText: 'Monto (COP)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Observación (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final monto = CurrencyInputFormatter.parseToDouble(amountCtrl.text) ?? 0;
    if (monto <= 0) return;

    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
    await ref
        .read(registerPaymentProvider.notifier)
        .registerManual(
          patientId: patientId,
          monto: monto,
          metodo: PaymentMethod.efectivo,
          adminId: adminId,
          notas: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
  }

  Future<void> _confirmAndPayu(
    BuildContext context,
    String patientId,
    String treatmentId,
    double monto,
    String patientEmail,
    String patientName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          '¿Deseas continuar con el pago por ${monto.toStringAsFixed(0)} COP?',
        ),
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
    if (treatmentId.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede iniciar el pago sin un tratamiento válido.'),
        ),
      );
      return;
    }

    await ref
        .read(initiatePayuPaymentProvider.notifier)
        .initiate(
          patientId: patientId,
          treatmentId: treatmentId,
          monto: monto,
          patientEmail: patientEmail,
          patientName: patientName,
          saldoPendiente: monto,
        );
  }
}

class _PatientHeaderChip extends StatelessWidget {
  const _PatientHeaderChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OcgColors.ivory,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PatientPaymentTreatmentCard extends StatelessWidget {
  const _PatientPaymentTreatmentCard({
    required this.treatment,
    required this.selected,
    required this.account,
    required this.onTap,
  });

  final PatientTreatment treatment;
  final bool selected;
  final PaymentModel? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final compact = MediaQuery.sizeOf(context).width < 380;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: compact ? 176 : 196,
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [const Color(0xFFFFFBF7), const Color(0xFFF4E8DD)]
                : [
                    OcgColors.ivory.withOpacity(0.16),
                    OcgColors.ivory.withOpacity(0.08),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFE2C4A7)
                : OcgColors.ivory.withOpacity(0.16),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A2C2016),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              treatment.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? OcgColors.espresso : OcgColors.ivory,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? OcgColors.espresso
                    : OcgColors.ivory.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                treatment.isPrimary ? 'Principal' : treatment.statusLabel,
                style: TextStyle(
                  color: selected ? OcgColors.ivory : OcgColors.ivory,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              account == null
                  ? 'Sin cuenta'
                  : 'Saldo ${currency.format(account!.saldoPendiente)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF6E5644)
                    : OcgColors.ivory.withOpacity(0.82),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientMetricChip extends StatelessWidget {
  const _PatientMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 106 : 120),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF8A6F59),
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: OcgColors.espresso,
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientPaymentSummaryCard extends StatelessWidget {
  const _PatientPaymentSummaryCard({
    required this.treatment,
    required this.payment,
    required this.currency,
  });

  final PatientTreatment treatment;
  final PaymentModel? payment;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final total = payment?.totalTratamiento ?? 0;
    final paid = payment?.montoPagado ?? 0;
    final pending = payment?.saldoPendiente ?? 0;
    final progress = total > 0
        ? ((paid / total) * 100).round().clamp(0, 100)
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF8), Color(0xFFF7EFE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treatment.displayName,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estado: ${treatment.statusLabel}',
                      style: const TextStyle(
                        color: Color(0xFF6E5644),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E7DB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$progress%',
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8D8C8),
              valueColor: const AlwaysStoppedAnimation<Color>(OcgColors.bronze),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PatientMetricChip(label: 'Total', value: currency.format(total)),
              _PatientMetricChip(label: 'Pagado', value: currency.format(paid)),
              _PatientMetricChip(
                label: 'Saldo',
                value: currency.format(pending),
              ),
              _PatientMetricChip(label: 'Avance', value: '$progress%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientFinancialBreakdownCard extends StatelessWidget {
  const _PatientFinancialBreakdownCard({
    required this.items,
    required this.currency,
  });

  final List<FinancialItemModel> items;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF8), Color(0xFFF7EFE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8D8C8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conceptos del tratamiento',
            style: TextStyle(
              color: OcgColors.espresso,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Desglose claro de lo que compone esta cuenta.',
            style: TextStyle(color: Color(0xFF8A6F59), fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Aún no hay conceptos detallados para este tratamiento.',
              style: TextStyle(color: Color(0xFF6E5644)),
            )
          else
            ...items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F3EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9DCD0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: OcgColors.espresso,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.supportsQuantity
                                ? 'Controles · ${item.effectiveQuantity} x ${currency.format(item.effectiveUnitAmount)}'
                                : item.kind,
                            style: const TextStyle(
                              color: Color(0xFF6E5644),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      currency.format(item.computedAmount),
                      style: const TextStyle(
                        color: OcgColors.bronze,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen financiero',
            style: TextStyle(
              color: Color(0xFF1A1410),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _money('Total tratamiento', currency.format(total)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _money(
                  'Pagado',
                  currency.format(pagado),
                  valueColor: const Color(0xFF166534),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _money(
                  'Pendiente',
                  currency.format(pendiente),
                  valueColor: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (progressPercent != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Avance de pago',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A6F59)),
                ),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progressPercent! / 100,
                backgroundColor: const Color(0xFFF2EDE8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  OcgColors.espresso,
                ),
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

  Widget _money(
    String label,
    String value, {
    Color valueColor = const Color(0xFF1A1410),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
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
            child: const Icon(
              Icons.calendar_today,
              size: 17,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximo pago',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo actual: ${currency.format(saldoPendiente)}',
                  style: const TextStyle(
                    color: Color(0xFF8A6F59),
                    fontSize: 12,
                  ),
                ),
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
  const _PendingCard({
    required this.saldoPendiente,
    required this.fechaProximoPago,
    required this.currency,
  });

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
                const Text(
                  'Pago pendiente',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Vencimiento: $fecha',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A6F59),
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(saldoPendiente),
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w700,
            ),
          ),
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
            child: const Icon(
              Icons.check_circle,
              size: 18,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _methodLabel(tx.metodo),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFmt.format(tx.fecha),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A6F59),
                  ),
                ),
                if ((tx.referencia ?? '').trim().isNotEmpty)
                  Text(
                    'Ref: ${tx.referencia}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8A6F59),
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
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
