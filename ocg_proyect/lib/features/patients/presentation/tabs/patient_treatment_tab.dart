import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../payments/data/models/financial_item_model.dart';
import '../../../payments/data/models/treatment_financial_summary_model.dart';
import '../../../payments/presentation/widgets/manage_financial_items_dialog.dart';
import '../../../payments/providers/treatment_financial_provider.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../../treatment/presentation/widgets/manage_patient_treatment_dialog.dart';
import '../../../treatment/presentation/widgets/stage_history_list.dart';
import '../../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../../treatment/presentation/widgets/update_stage_dialog.dart';
import '../../../treatment/providers/patient_treatments_provider.dart';
import '../../../treatment/providers/treatment_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_button.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientTreatmentTab extends ConsumerStatefulWidget {
  const PatientTreatmentTab({
    super.key,
    required this.patientId,
    required this.patient,
  });

  final String patientId;
  final PatientModel patient;

  @override
  ConsumerState<PatientTreatmentTab> createState() => _PatientTreatmentTabState();
}

class _PatientTreatmentTabState extends ConsumerState<PatientTreatmentTab> {
  String? _selectedTreatmentId;

  @override
  Widget build(BuildContext context) {
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((patientId: widget.patientId, patient: widget.patient)),
    );
    final saveState = ref.watch(savePatientTreatmentProvider);

    if (treatments.length == 1 &&
        treatments.first.id.startsWith('legacy-primary-') &&
        !saveState.isLoading) {
      Future.microtask(() {
        ref.read(savePatientTreatmentProvider.notifier).migrateLegacyPatientIfNeeded(
              patient: widget.patient,
              createdBy: ref.read(authStateProvider).asData?.value?.uid ?? 'system-migration',
            );
      });
    }

    if (treatments.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tratamientos del paciente',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OcgEmptyState(
              icon: Icons.medical_services_outlined,
              title: 'Este paciente todavía no tiene tratamiento',
              subtitle:
                  'Crea el primer tratamiento desde aquí para que quede persistido y visible al recargar.',
              ctaLabel: saveState.isLoading ? null : 'Crear tratamiento',
              onCta: saveState.isLoading
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => ManagePatientTreatmentDialog(
                          patientId: widget.patientId,
                          patientName: widget.patient.nombre,
                        ),
                      ),
            ),
          ],
        ),
      );
    }

    final selectedTreatment = _resolveSelectedTreatment(treatments);
    if (!selectedTreatment.id.startsWith('legacy-primary-')) {
      Future.microtask(() => ref.read(treatmentFinancialRepositoryProvider).ensureBaseItems(
            patientId: widget.patientId,
            treatment: selectedTreatment,
          ));
    }
    final financialItemsAsync = selectedTreatment.id.startsWith('legacy-primary-')
        ? const AsyncValue<List<FinancialItemModel>>.data(<FinancialItemModel>[])
        : ref.watch(
            treatmentFinancialItemsProvider(
              (patientId: widget.patientId, treatmentId: selectedTreatment.id),
            ),
          );
    final historyAsync = selectedTreatment.id.startsWith('legacy-primary-')
        ? ref.watch(stageHistoryProvider(widget.patientId))
        : ref.watch(
            treatmentStageHistoryProvider(
              (patientId: widget.patientId, treatmentId: selectedTreatment.id),
            ),
          );
    final adminId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: OcgEmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo cargar el historial',
          subtitle: '$error',
        ),
      ),
      data: (historial) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tratamientos del paciente',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Nuevo tratamiento',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ManagePatientTreatmentDialog(
                      patientId: widget.patientId,
                      patientName: widget.patient.nombre,
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.08)),
              ),
              child: Text(
                'Tratamiento visible por defecto: ${selectedTreatment.displayName}${selectedTreatment.isPrimary ? ' (principal)' : ''} · ${treatments.length} total(es)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final treatment in treatments)
                  ChoiceChip(
                    selected: treatment.id == selectedTreatment.id,
                    label: Text(treatment.displayName),
                    avatar: treatment.isPrimary
                        ? const Icon(Icons.star, size: 16, color: OcgColors.espresso)
                        : null,
                    selectedColor: OcgColors.bronze.withValues(alpha: 0.18),
                    backgroundColor: treatment.isFinished ? OcgColors.mist : OcgColors.ivory,
                    side: BorderSide(
                      color: treatment.id == selectedTreatment.id
                          ? OcgColors.bronze
                          : OcgColors.espresso.withValues(alpha: 0.14),
                    ),
                    onSelected: (_) => setState(() => _selectedTreatmentId = treatment.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedTreatment.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: OcgColors.espresso,
                              ),
                        ),
                      ),
                      _StatusPill(label: selectedTreatment.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaItem(
                        icon: Icons.category_outlined,
                        label: 'Categoría',
                        value: PatientTreatment.labelForBaseTreatment(selectedTreatment.categoria),
                      ),
                      _MetaItem(
                        icon: Icons.medical_services_outlined,
                        label: 'Tipo base',
                        value: PatientTreatment.labelForBaseTreatment(selectedTreatment.tipoBase),
                      ),
                      if (selectedTreatment.normalizedSubtypeLabel != null)
                        _MetaItem(
                          icon: Icons.style_outlined,
                          label: 'Subtipo',
                          value: selectedTreatment.normalizedSubtypeLabel!,
                        ),
                      _MetaItem(
                        icon: Icons.timeline_outlined,
                        label: 'Etapa',
                        value: stageNames[selectedTreatment.etapaActual] ?? selectedTreatment.etapaActual.name,
                      ),
                      _MetaItem(
                        icon: selectedTreatment.isPrimary ? Icons.star : Icons.layers_outlined,
                        label: 'Prioridad',
                        value: selectedTreatment.isPrimary ? 'Principal' : 'Secundario',
                      ),
                      _MetaItem(
                        icon: Icons.cleaning_services_outlined,
                        label: 'Limpieza',
                        value: 'Cada ${selectedTreatment.suggestedCleaningEveryMonths} meses',
                      ),
                      _MetaItem(
                        icon: Icons.event_repeat_outlined,
                        label: 'Control',
                        value: 'Cada ${selectedTreatment.suggestedControlEveryMonths} meses',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OcgColors.ivory,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
                    ),
                    child: const Text(
                      'La parte financiera de este tratamiento se configura por conceptos en el constructor dinámico de pagos. El total y el saldo ya no deben tratarse como campos manuales independientes.',
                      style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if ((selectedTreatment.notas ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      selectedTreatment.notas!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 180,
                        child: OcgButton(
                          label: 'Editar tratamiento',
                          variant: OcgButtonVariant.outline,
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ManagePatientTreatmentDialog(
                              patientId: widget.patientId,
                              patientName: widget.patient.nombre,
                              initialTreatment: selectedTreatment,
                            ),
                          ),
                        ),
                      ),
                      if (!selectedTreatment.isPrimary && !selectedTreatment.id.startsWith('legacy-primary-'))
                        SizedBox(
                          width: 180,
                          child: OcgButton(
                            label: 'Hacer principal',
                            variant: OcgButtonVariant.ghost,
                            isLoading: saveState.isLoading,
                            onPressed: () async {
                              await ref.read(savePatientTreatmentProvider.notifier).setPrimaryTreatment(
                                    patientId: widget.patientId,
                                    treatment: selectedTreatment.copyWith(isPrimary: true),
                                  );
                            },
                          ),
                        ),
                      if (!selectedTreatment.id.startsWith('legacy-primary-'))
                        SizedBox(
                          width: 180,
                          child: OcgButton(
                            label: 'Editar conceptos',
                            variant: OcgButtonVariant.ghost,
                            onPressed: () {
                              final items = financialItemsAsync.asData?.value ?? const <FinancialItemModel>[];
                              showDialog<void>(
                                context: context,
                                builder: (_) => ManageFinancialItemsDialog(
                                  patientId: widget.patientId,
                                  treatment: selectedTreatment,
                                  initialItems: items,
                                ),
                              );
                            },
                          ),
                        ),
                      if (!selectedTreatment.id.startsWith('legacy-primary-'))
                        SizedBox(
                          width: 180,
                          child: OcgButton(
                            label: selectedTreatment.isFinished ? 'Reactivar' : 'Finalizar',
                            variant: OcgButtonVariant.ghost,
                            isLoading: saveState.isLoading,
                            onPressed: () async {
                              final newStatus = selectedTreatment.isFinished ? 'activo' : 'finalizado';
                              await ref.read(savePatientTreatmentProvider.notifier).updateTreatmentStatus(
                                    patientId: widget.patientId,
                                    treatment: selectedTreatment,
                                    newStatus: newStatus,
                                  );
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            financialItemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OcgColors.error.withValues(alpha: 0.22)),
                ),
                child: Text('No se pudieron cargar los conceptos financieros: $error'),
              ),
              data: (items) => _TreatmentFinancialOverview(
                patientId: widget.patientId,
                treatment: selectedTreatment,
                items: items,
              ),
            ),
            const SizedBox(height: 20),
            TreatmentTimeline(
              etapaActual: selectedTreatment.etapaActual,
              historial: historial,
              isAdmin: true,
              onAdvanceStage: () => showDialog<void>(
                context: context,
                builder: (_) => UpdateStageDialog(
                  patientId: widget.patientId,
                  treatmentId: selectedTreatment.id.startsWith('legacy-primary-')
                      ? null
                      : selectedTreatment.id,
                  etapaActual: selectedTreatment.etapaActual,
                  adminId: adminId,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Historial de cambios',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            StageHistoryList(historial: historial, isAdmin: true),
          ],
        ),
      ),
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

class _TreatmentFinancialOverview extends StatelessWidget {
  const _TreatmentFinancialOverview({
    required this.patientId,
    required this.treatment,
    required this.items,
  });

  final String patientId;
  final PatientTreatment treatment;
  final List<FinancialItemModel> items;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);
    final activeItems = items.where((item) => item.active).toList()..sort((a, b) => a.order.compareTo(b.order));
    final total = activeItems.fold<double>(0, (sum, item) => sum + item.amount);
    final paid = ((treatment.totalTratamiento ?? 0) - (treatment.saldoPendiente ?? 0))
        .clamp(0, double.infinity)
        .toDouble();
    final summary = TreatmentFinancialSummaryModel(
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0,
      totalAmount: total,
      paidAmount: paid,
      pendingAmount: (total - paid).clamp(0, double.infinity).toDouble(),
      itemsCount: activeItems.length,
      lastPricingUpdateAt: DateTime.now(),
    );

    return Column(
      children: [
        Container(
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
                  Expanded(
                    child: Text(
                      'Conceptos del tratamiento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: OcgColors.espresso,
                          ),
                    ),
                  ),
                  Text(
                    '${summary.itemsCount} activos',
                    style: const TextStyle(
                      color: OcgColors.bronze,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Estructura financiera visible del tratamiento: Inicial, Controles, concepto base condicional y extras.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OcgColors.espresso.withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 14),
              if (activeItems.isEmpty)
                const Text(
                  'Aún no hay conceptos activos configurados para este tratamiento.',
                  style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
                )
              else
                ...activeItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: OcgColors.mist,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.08)),
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FinancialBadge(
                                      label: item.isRequired ? 'Obligatorio' : 'Opcional',
                                      background: item.isRequired
                                          ? const Color(0xFFFFF2DB)
                                          : const Color(0xFFF1F3F5),
                                    ),
                                    _FinancialBadge(
                                      label: 'Orden ${item.order}',
                                      background: const Color(0xFFEDE7DF),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${currency.format(item.amount)} COP',
                            style: const TextStyle(
                              color: OcgColors.espresso,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monto total del tratamiento',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: OcgColors.espresso,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${currency.format(summary.totalAmount)} COP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: OcgColors.espresso,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Autocalculado desde los conceptos activos; no es un valor manual plano.',
                style: TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _FinancialSummaryRow(label: 'Moneda', value: summary.currency),
              _FinancialSummaryRow(label: 'Subtotal', value: '${currency.format(summary.subtotalAmount)} COP'),
              _FinancialSummaryRow(label: 'Descuento', value: '${currency.format(summary.discountAmount)} COP'),
              _FinancialSummaryRow(label: 'Total', value: '${currency.format(summary.totalAmount)} COP', emphasize: true),
              _FinancialSummaryRow(label: 'Pagado', value: '${currency.format(summary.paidAmount)} COP'),
              _FinancialSummaryRow(
                label: 'Saldo pendiente',
                value: '${currency.format(summary.pendingAmount)} COP',
                emphasize: true,
              ),
              _FinancialSummaryRow(label: 'Conceptos activos', value: '${summary.itemsCount}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinancialBadge extends StatelessWidget {
  const _FinancialBadge({required this.label, required this.background});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OcgColors.espresso,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FinancialSummaryRow extends StatelessWidget {
  const _FinancialSummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: OcgColors.espresso,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      fontSize: emphasize ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.espresso.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: OcgColors.bronze),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OcgColors.bronze,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OcgColors.bronze.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OcgColors.espresso,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
