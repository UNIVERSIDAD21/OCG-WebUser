import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/patients/data/models/patient_data_resolution.dart';
import '../../../../features/payments/data/models/financial_item_model.dart';
import '../../../../features/payments/providers/payments_provider.dart';
import '../../../../features/payments/presentation/widgets/manage_financial_items_dialog.dart';
import '../../../../features/payments/presentation/widgets/register_payment_dialog.dart';
import '../../../../features/payments/presentation/widgets/transaction_list.dart';
import '../../../../features/payments/providers/treatment_financial_provider.dart';
import '../../../../features/treatment/data/models/patient_treatment.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../providers/patients_provider.dart';

class PatientPaymentsTab extends ConsumerStatefulWidget {
  const PatientPaymentsTab({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientPaymentsTab> createState() => _PatientPaymentsTabState();
}

class _PatientPaymentsTabState extends ConsumerState<PatientPaymentsTab> {
  String? _selectedTreatmentId;

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('No se pudo cargar paciente: $error'),
      data: (patient) {
        if (patient == null) {
          return const OcgEmptyState(
            icon: Icons.person_off,
            title: 'Paciente no encontrado',
          );
        }

        final resolution = ref.watch(
          effectivePatientPaymentsProvider((
            patientId: widget.patientId,
            patient: patient,
          )),
        );
        final treatments = resolution.treatments;
        final selectedTreatment = _resolveSelectedTreatment(treatments);

        if (!selectedTreatment.id.startsWith('legacy-primary-')) {
          Future.microtask(
            () => ref.read(ensureTreatmentFinancialItemsProvider)(
              widget.patientId,
              selectedTreatment,
            ),
          );
        }

        final financialItemsAsync = ref.watch(
          treatmentFinancialItemsProvider((
            patientId: widget.patientId,
            treatmentId: selectedTreatment.id,
          )),
        );
        final selectedAccount = resolution.paymentAccounts
            .cast<EffectivePatientPaymentAccount?>()
            .firstWhere(
              (item) => item?.treatmentId == selectedTreatment.id,
              orElse: () => null,
            );
        final globalTotal = resolution.paymentAccounts.fold<double>(
          0,
          (sum, account) => sum + account.payment.totalTratamiento,
        );
        final globalPaid = resolution.paymentAccounts.fold<double>(
          0,
          (sum, account) => sum + account.payment.montoPagado,
        );
        final globalPending = resolution.paymentAccounts.fold<double>(
          0,
          (sum, account) => sum + account.payment.saldoPendiente,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pagos del paciente',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Resumen global agregado + cuentas por tratamiento. Los pagos manuales siempre se registran contra una cuenta específica.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: OcgColors.bronze),
              ),
              const SizedBox(height: 16),
              _GlobalPaymentsSummary(
                total: globalTotal,
                paid: globalPaid,
                pending: globalPending,
                mode: resolution.mode,
              ),
              const SizedBox(height: 16),
              Text(
                'Cuentas por tratamiento',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (resolution.paymentAccounts.isEmpty)
                const OcgEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No hay cuentas de pago todavía.',
                  subtitle:
                      'Cuando se inicialicen cuentas legacy o por tratamiento aparecerán aquí.',
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final account in resolution.paymentAccounts)
                      _PaymentAccountCard(
                        account: account,
                        treatment: account.treatmentId == null
                            ? null
                            : treatments
                                  .cast<PatientTreatment?>()
                                  .firstWhere(
                                    (item) => item?.id == account.treatmentId,
                                    orElse: () => null,
                                  ),
                        selected: account.treatmentId == selectedTreatment.id,
                        onSelect: account.treatmentId == null
                            ? null
                            : () => setState(() {
                                _selectedTreatmentId = account.treatmentId;
                              }),
                        onRegister: account.treatmentId == null
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (_) => RegisterPaymentDialog(
                                  patientId: widget.patientId,
                                  treatmentId: account.treatmentId,
                                  saldoPendiente:
                                      account.payment.saldoPendiente,
                                ),
                              ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              _PaymentAccountBanner(
                treatment: selectedTreatment,
                nextPaymentDate: selectedAccount?.payment.fechaProximoPago,
              ),
              const SizedBox(height: 16),
              financialItemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('No se pudieron cargar conceptos: $error'),
                data: (items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TreatmentFinanceSummary(
                      treatment: selectedTreatment,
                      items: items,
                    ),
                    const SizedBox(height: 16),
                    _FinancialItemsSection(
                      patientId: widget.patientId,
                      treatment: selectedTreatment,
                      items: items,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: selectedAccount?.treatmentId == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => RegisterPaymentDialog(
                          patientId: widget.patientId,
                          treatmentId: selectedAccount!.treatmentId,
                          saldoPendiente:
                              selectedAccount.payment.saldoPendiente,
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: Text(
                  'Registrar pago en ${selectedTreatment.displayName}',
                ),
              ),
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
                patientId: widget.patientId,
                treatmentId: selectedTreatment.id,
              ),
            ],
          ),
        );
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
    return treatments.first;
  }
}

class _GlobalPaymentsSummary extends StatelessWidget {
  const _GlobalPaymentsSummary({
    required this.total,
    required this.paid,
    required this.pending,
    required this.mode,
  });

  final double total;
  final double paid;
  final double pending;
  final PatientDataMode mode;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resumen global del paciente',
                  style: TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                switch (mode) {
                  PatientDataMode.legacyPuro => 'LEGACY',
                  PatientDataMode.nuevoPuro => 'NUEVO',
                  PatientDataMode.mixto => 'MIXTO',
                },
                style: const TextStyle(
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryMetric(label: 'Total', value: currency.format(total)),
              _SummaryMetric(label: 'Pagado', value: currency.format(paid)),
              _SummaryMetric(label: 'Saldo', value: currency.format(pending)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentAccountCard extends StatelessWidget {
  const _PaymentAccountCard({
    required this.account,
    required this.treatment,
    required this.selected,
    required this.onSelect,
    required this.onRegister,
  });

  final EffectivePatientPaymentAccount account;
  final PatientTreatment? treatment;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final treatmentTitle = account.treatmentId == null
        ? 'Cuenta legacy'
        : (treatment?.displayName.isNotEmpty == true
              ? treatment!.displayName
              : 'Tratamiento sin nombre');
    final treatmentType = treatment == null
        ? 'Legacy / transición'
        : PatientTreatment.labelForBaseTreatment(treatment!.tipoBase);

    return SizedBox(
      width: 340,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF8F0E7) : OcgColors.ivory,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? OcgColors.espresso : const Color(0xFFE8DDD2),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x141A1410),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
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
                          treatmentTitle,
                          style: const TextStyle(
                            color: OcgColors.espresso,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          treatmentType,
                          style: const TextStyle(color: OcgColors.bronze),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? OcgColors.espresso
                          : const Color(0xFFF3ECE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      selected ? 'Cuenta activa' : 'Seleccionar',
                      style: TextStyle(
                        color: selected ? OcgColors.ivory : OcgColors.espresso,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AccountMetric(
                    label: 'Total',
                    value: currency.format(account.payment.totalTratamiento),
                  ),
                  _AccountMetric(
                    label: 'Pagado',
                    value: currency.format(account.payment.montoPagado),
                  ),
                  _AccountMetric(
                    label: 'Saldo',
                    value: currency.format(account.payment.saldoPendiente),
                    emphasis: true,
                  ),
                ],
              ),
              if (account.payment.fechaProximoPago != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Próximo pago: ${DateFormat('dd/MM/yyyy').format(account.payment.fechaProximoPago!)}',
                  style: const TextStyle(color: OcgColors.ink),
                ),
              ],
              if (treatment != null) ...[
                const SizedBox(height: 6),
                Text(
                  treatment!.isPrimary
                      ? 'Tratamiento principal del paciente'
                      : 'Tratamiento secundario',
                  style: const TextStyle(color: OcgColors.bronze),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.add_card_outlined, size: 16),
                  label: Text(
                    selected ? 'Registrar pago en esta cuenta' : 'Usar esta cuenta y registrar pago',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: emphasis ? const Color(0xFFF6E9DD) : const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: OcgColors.bronze,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: emphasis ? OcgColors.espresso : OcgColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentAccountBanner extends StatelessWidget {
  const _PaymentAccountBanner({
    required this.treatment,
    required this.nextPaymentDate,
  });

  final PatientTreatment treatment;
  final DateTime? nextPaymentDate;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuenta financiera activa: ${treatment.displayName}',
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextPaymentDate == null
                ? 'Próximo pago no definido para este tratamiento.'
                : 'Próximo pago de este tratamiento: ${formatter.format(nextPaymentDate!)}',
            style: const TextStyle(color: OcgColors.ink),
          ),
        ],
      ),
    );
  }
}

class _TreatmentFinanceSummary extends StatelessWidget {
  const _TreatmentFinanceSummary({
    required this.treatment,
    required this.items,
  });

  final PatientTreatment treatment;
  final List<FinancialItemModel> items;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );
    final activeItems = items.where((item) => item.active).toList();
    final total = activeItems.fold<double>(0, (sum, item) => sum + item.amount);
    final saldo = treatment.saldoPendiente ?? 0;
    final pagado = (total - saldo).clamp(0, double.infinity).toDouble();
    final conditionalBase = treatment.tipoBase == 'ortopedia'
        ? 'Aparato 1'
        : 'Retenedores';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _SummaryItem(label: 'Tratamiento', value: treatment.displayName),
              _SummaryItem(
                label: 'Tipo',
                value: PatientTreatment.labelForBaseTreatment(
                  treatment.tipoBase,
                ),
              ),
              if (treatment.normalizedSubtypeLabel != null)
                _SummaryItem(
                  label: 'Subtipo',
                  value: treatment.normalizedSubtypeLabel!,
                ),
              _SummaryItem(
                label: 'Total del tratamiento',
                value: currency.format(total),
              ),
              _SummaryItem(
                label: 'Pagado del tratamiento',
                value: currency.format(pagado),
              ),
              _SummaryItem(
                label: 'Pendiente del tratamiento',
                value: currency.format(saldo),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fuente de verdad: conceptos financieros del tratamiento seleccionado. Base esperada: Inicial + Controles + $conditionalBase.',
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: OcgColors.bronze,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialItemsSection extends ConsumerWidget {
  const _FinancialItemsSection({
    required this.patientId,
    required this.treatment,
    required this.items,
  });

  final String patientId;
  final PatientTreatment treatment;
  final List<FinancialItemModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeItems = items.where((item) => item.active).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Constructor dinámico de pagos',
                  style: TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ManageFinancialItemsDialog(
                    patientId: patientId,
                    treatment: treatment,
                    initialItems: items,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar conceptos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Aquí defines el valor real del tratamiento por conceptos. Si editas montos o activas/desactivas conceptos, solo cambia el saldo del tratamiento seleccionado.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OcgColors.bronze,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (activeItems.isEmpty)
            const OcgEmptyState(
              icon: Icons.payments_outlined,
              title: 'Aún no hay conceptos activos',
              subtitle:
                  'Edita el tratamiento para construir el desglose financiero.',
            )
          else
            for (final item in activeItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: OcgColors.espresso,
                            ),
                          ),
                          Text(
                            item.isRequired ? 'Obligatorio' : 'Opcional',
                            style: TextStyle(
                              color: item.isRequired
                                  ? OcgColors.bronze
                                  : OcgColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'es_CO',
                        symbol: r'$',
                        decimalDigits: 0,
                      ).format(item.amount),
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
