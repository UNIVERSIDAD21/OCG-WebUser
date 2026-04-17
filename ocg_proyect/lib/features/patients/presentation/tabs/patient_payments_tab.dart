import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/payments/data/models/financial_item_model.dart';
import '../../../../features/payments/presentation/widgets/manage_financial_items_dialog.dart';
import '../../../../features/payments/presentation/widgets/register_payment_dialog.dart';
import '../../../../features/payments/presentation/widgets/transaction_list.dart';
import '../../../../features/payments/providers/treatment_financial_provider.dart';
import '../../../../features/treatment/data/models/patient_treatment.dart';
import '../../../../features/treatment/providers/patient_treatments_provider.dart';
import '../../../auth/providers/auth_providers.dart';
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
    final treatmentsAsync = ref.watch(patientTreatmentsProvider(widget.patientId));

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('No se pudo cargar paciente: $error'),
      data: (patient) {
        if (patient == null) {
          return const OcgEmptyState(icon: Icons.person_off, title: 'Paciente no encontrado');
        }

        final remoteTreatments = treatmentsAsync.asData?.value ?? const <PatientTreatment>[];
        final treatments = remoteTreatments.isNotEmpty
            ? remoteTreatments
            : <PatientTreatment>[PatientTreatment.fromLegacyPatient(patient)];
        if (remoteTreatments.isEmpty && patient.tipoTratamiento != null) {
          Future.microtask(() => ref.read(savePatientTreatmentProvider.notifier).migrateLegacyPatientIfNeeded(
                patient: patient,
                createdBy: ref.read(authStateProvider).asData?.value?.uid ?? 'system-migration',
              ));
        }
        final selectedTreatment = _resolveSelectedTreatment(treatments);
        if (!selectedTreatment.id.startsWith('legacy-primary-')) {
          Future.microtask(() => ref.read(treatmentFinancialRepositoryProvider).ensureBaseItems(
                patientId: widget.patientId,
                treatment: selectedTreatment,
              ));
        }

        final financialItemsAsync = ref.watch(
          treatmentFinancialItemsProvider((patientId: widget.patientId, treatmentId: selectedTreatment.id)),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pagos por tratamiento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final treatment in treatments)
                    ChoiceChip(
                      selected: selectedTreatment.id == treatment.id,
                      label: Text(treatment.displayName),
                      onSelected: (_) => setState(() => _selectedTreatmentId = treatment.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _TreatmentFinanceSummary(treatment: selectedTreatment),
              const SizedBox(height: 16),
              financialItemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('No se pudieron cargar conceptos: $error'),
                data: (items) => _FinancialItemsSection(
                  patientId: widget.patientId,
                  treatment: selectedTreatment,
                  items: items,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Próximo pago',
                      style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    patient.fechaProximoPago == null
                        ? 'No definido'
                        : DateFormat('dd/MM/yyyy').format(patient.fechaProximoPago!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RegisterPaymentDialog(
                    patientId: widget.patientId,
                    treatmentId: selectedTreatment.id,
                    saldoPendiente: selectedTreatment.saldoPendiente ?? 0,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Registrar pago'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Historial de transacciones',
                style: TextStyle(color: OcgColors.espresso, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TransactionList(patientId: widget.patientId, treatmentId: selectedTreatment.id),
            ],
          ),
        );
      },
    );
  }

  PatientTreatment _resolveSelectedTreatment(List<PatientTreatment> treatments) {
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

class _TreatmentFinanceSummary extends StatelessWidget {
  const _TreatmentFinanceSummary({required this.treatment});

  final PatientTreatment treatment;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    final total = treatment.totalTratamiento ?? 0;
    final saldo = treatment.saldoPendiente ?? 0;
    final pagado = (total - saldo).clamp(0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          _SummaryItem(label: 'Tratamiento', value: treatment.displayName),
          _SummaryItem(label: 'Total calculado', value: currency.format(total)),
          _SummaryItem(label: 'Pagado', value: currency.format(pagado)),
          _SummaryItem(label: 'Saldo pendiente', value: currency.format(saldo)),
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
          Text(label, style: const TextStyle(color: OcgColors.bronze, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700)),
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
                  style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700, fontSize: 16),
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
          const SizedBox(height: 12),
          if (activeItems.isEmpty)
            const OcgEmptyState(
              icon: Icons.payments_outlined,
              title: 'Aún no hay conceptos activos',
              subtitle: 'Edita el tratamiento para construir el desglose financiero.',
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
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
                          Text(
                            item.isRequired ? 'Obligatorio' : 'Opcional',
                            style: TextStyle(color: item.isRequired ? OcgColors.bronze : OcgColors.ink),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0).format(item.amount),
                      style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
