import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../payments/data/models/financial_item_model.dart';
import '../../../payments/data/models/treatment_financial_summary_model.dart';
import '../../../payments/presentation/widgets/manage_financial_items_dialog.dart';
import '../../../payments/providers/treatment_financial_provider.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../../../treatment/data/models/stage_history_entry.dart';
import '../../../treatment/presentation/widgets/manage_patient_treatment_dialog.dart';
import '../../../treatment/presentation/widgets/stage_history_list.dart';
import '../../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../../treatment/presentation/widgets/update_stage_dialog.dart';
import '../../../treatment/providers/patient_treatments_provider.dart';
import '../../../treatment/providers/treatment_provider.dart';
import '../../data/models/patient_data_resolution.dart';
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
  ConsumerState<PatientTreatmentTab> createState() =>
      _PatientTreatmentTabState();
}

class _PatientTreatmentTabState extends ConsumerState<PatientTreatmentTab> {
  String? _selectedTreatmentId;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((
        patientId: widget.patientId,
        patient: widget.patient,
      )),
    );
    final saveState = ref.watch(savePatientTreatmentProvider);
    final patientDataMode = ref.watch(
      patientDataModeProvider((
        patientId: widget.patientId,
        patient: widget.patient,
      )),
    );

    if (treatments.length == 1 &&
        treatments.first.id.startsWith('legacy-primary-') &&
        !saveState.isLoading) {
      Future.microtask(() {
        ref
            .read(savePatientTreatmentProvider.notifier)
            .migrateLegacyPatientIfNeeded(
              patient: widget.patient,
              createdBy:
                  ref.read(authStateProvider).asData?.value?.uid ??
                  'system-migration',
            );
      });
    }

    if (treatments.isEmpty) {
      return _buildEmptyState(context, saveState.isLoading);
    }

    final selectedTreatment = _resolveSelectedTreatment(treatments);
    if (!selectedTreatment.id.startsWith('legacy-primary-')) {
      Future.microtask(
        () => ref.read(ensureTreatmentFinancialItemsProvider)(
          widget.patientId,
          selectedTreatment,
        ),
      );
    }

    final financialItemsAsync =
        selectedTreatment.id.startsWith('legacy-primary-')
        ? const AsyncValue<List<FinancialItemModel>>.data(
            <FinancialItemModel>[],
          )
        : ref.watch(
            treatmentFinancialItemsProvider((
              patientId: widget.patientId,
              treatmentId: selectedTreatment.id,
            )),
          );

    final historyAsync = selectedTreatment.id.startsWith('legacy-primary-')
        ? ref.watch(stageHistoryProvider(widget.patientId))
        : ref.watch(
            treatmentStageHistoryProvider((
              patientId: widget.patientId,
              treatmentId: selectedTreatment.id,
            )),
          );

    final adminId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    return financialItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: OcgEmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo cargar la configuración financiera',
          subtitle: '$error',
        ),
      ),
      data: (financialItems) {
        final summary = _buildFinancialSummary(
          selectedTreatment,
          financialItems,
        );
        final activeItems = financialItems.where((item) => item.active).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        return historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: OcgEmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar el historial de etapas',
              subtitle: '$error',
            ),
          ),
          data: (history) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(
                  context,
                  treatments,
                  selectedTreatment,
                  summary,
                  saveState.isLoading,
                ),
                const SizedBox(height: 18),
                _buildTreatmentSelector(
                  treatments,
                  selectedTreatment,
                  patientDataMode,
                ),
                const SizedBox(height: 18),
                _buildSummaryGrid(selectedTreatment, treatments, summary),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final singleColumn = constraints.maxWidth < 1180;
                    if (singleColumn) {
                      return Column(
                        children: [
                          _buildClinicalColumn(
                            context,
                            selectedTreatment,
                            treatments,
                            history,
                            adminId,
                          ),
                          const SizedBox(height: 18),
                          _buildFinancialColumn(
                            context,
                            selectedTreatment,
                            summary,
                            activeItems,
                            financialItems,
                            saveState.isLoading,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildClinicalColumn(
                            context,
                            selectedTreatment,
                            treatments,
                            history,
                            adminId,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 9,
                          child: _buildFinancialColumn(
                            context,
                            selectedTreatment,
                            summary,
                            activeItems,
                            financialItems,
                            saveState.isLoading,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: OcgColors.ivory,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE8DED2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100D0A07),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: OcgEmptyState(
          icon: Icons.medical_services_outlined,
          title: 'Este paciente todavía no tiene tratamiento',
          subtitle:
              'Crea el primer tratamiento para habilitar el overview clínico, financiero y el seguimiento por etapas.',
          ctaLabel: isLoading ? null : 'Crear tratamiento',
          onCta: isLoading
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => ManagePatientTreatmentDialog(
                    patientId: widget.patientId,
                    patientName: widget.patient.nombre,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    List<PatientTreatment> treatments,
    PatientTreatment selectedTreatment,
    TreatmentFinancialSummaryModel summary,
    bool isSaving,
  ) {
    final count = treatments.length;
    final isPrimary = selectedTreatment.isPrimary;
    final primaryLabel = isPrimary
        ? 'Tratamiento principal activo'
        : 'Tratamiento secundario';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8DED2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D0A07),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 980;
              final heroInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCG — Módulo de tratamiento',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF908C88),
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedTreatment.displayName,
                    key: const ValueKey('selected-treatment-title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1A1208),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.patient.nombre} · ${PatientTreatment.labelForBaseTreatment(selectedTreatment.tipoBase)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF908C88),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroTag(
                        icon: Icons.star_outline,
                        label: primaryLabel,
                        accent: const Color(0xFFB07D3C),
                        background: const Color(0xFFF0E4CC),
                      ),
                      _HeroTag(
                        icon: Icons.layers_outlined,
                        label: '$count tratamiento${count == 1 ? '' : 's'}',
                        accent: OcgColors.espresso,
                        background: const Color(0xFFF5F1EA),
                      ),
                      _HeroTag(
                        icon: Icons.flag_outlined,
                        label: selectedTreatment.statusLabel,
                        accent: const Color(0xFF7A5010),
                        background: const Color(0xFFFFF4D8),
                      ),
                      _HeroTag(
                        icon: Icons.timeline_outlined,
                        label:
                            stageNames[selectedTreatment.etapaActual] ??
                            selectedTreatment.etapaActual.name,
                        accent: const Color(0xFF1B4332),
                        background: const Color(0xFFEAF5EE),
                      ),
                    ],
                  ),
                ],
              );

              final heroActions = Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  _HeroActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Editar tratamiento',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ManagePatientTreatmentDialog(
                        patientId: widget.patientId,
                        patientName: widget.patient.nombre,
                        initialTreatment: selectedTreatment,
                      ),
                    ),
                  ),
                  if (!selectedTreatment.id.startsWith('legacy-primary-'))
                    _HeroActionButton(
                      icon: Icons.account_tree_outlined,
                      label: 'Cambiar etapa',
                      filled: true,
                      onPressed: () =>
                          _openUpdateStageDialog(selectedTreatment),
                    ),
                  if (!selectedTreatment.isPrimary &&
                      !selectedTreatment.id.startsWith('legacy-primary-'))
                    _HeroActionButton(
                      icon: Icons.star_border,
                      label: isSaving ? 'Guardando...' : 'Hacer principal',
                      onPressed: isSaving
                          ? null
                          : () async {
                              await ref
                                  .read(savePatientTreatmentProvider.notifier)
                                  .setPrimaryTreatment(
                                    patientId: widget.patientId,
                                    treatment: selectedTreatment.copyWith(
                                      isPrimary: true,
                                    ),
                                  );
                            },
                    ),
                ],
              );

              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heroInfo, const SizedBox(height: 16), heroActions],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heroInfo),
                  const SizedBox(width: 16),
                  Flexible(child: heroActions),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 920;
              final cards = [
                _MetricHeroCard(
                  label: 'Monto total del tratamiento',
                  value: _currency.format(summary.totalAmount),
                  supporting: 'Autocalculado por conceptos activos',
                  highlighted: true,
                ),
                _MetricHeroCard(
                  label: 'Saldo pendiente',
                  value: _currency.format(summary.pendingAmount),
                  supporting: 'Pagado: ${_currency.format(summary.paidAmount)}',
                ),
                _MetricHeroCard(
                  label: 'Frecuencia de control',
                  value:
                      'Cada ${selectedTreatment.suggestedControlEveryMonths} meses',
                  supporting:
                      'Limpieza cada ${selectedTreatment.suggestedCleaningEveryMonths} meses',
                ),
              ];
              if (compact) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentSelector(
    List<PatientTreatment> treatments,
    PatientTreatment selectedTreatment,
    PatientDataMode patientDataMode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tratamientos del paciente',
            style: TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            patientDataMode == PatientDataMode.mixto
                ? 'Paciente en transición legacy + nuevo. La lista combina todos los tratamientos reales sin ocultar los secundarios.'
                : 'Cada tratamiento se muestra como una línea clínica/financiera independiente. El principal se destaca, pero los secundarios siguen visibles.',
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final treatment in treatments)
                _TreatmentStreamCard(
                  key: ValueKey('treatment-stream-${treatment.id}'),
                  treatment: treatment,
                  selected: treatment.id == selectedTreatment.id,
                  currency: _currency,
                  onTap: () =>
                      setState(() => _selectedTreatmentId = treatment.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(
    PatientTreatment selectedTreatment,
    List<PatientTreatment> treatments,
    TreatmentFinancialSummaryModel summary,
  ) {
    final paid = summary.paidAmount;
    final cards = [
      _CompactInsightCard(
        title: 'Etapa actual',
        value:
            stageNames[selectedTreatment.etapaActual] ??
            selectedTreatment.etapaActual.name,
        subtitle: 'Tracking clínico del tratamiento activo',
      ),
      _CompactInsightCard(
        title: 'Progreso del tratamiento',
        value: '${_stageProgress(selectedTreatment.etapaActual)}%',
        subtitle: 'Basado en la línea de etapas estándar',
      ),
      _CompactInsightCard(
        title: 'Pagado',
        value: _currency.format(paid),
        subtitle: 'Pagos acumulados del tratamiento visible',
      ),
      _CompactInsightCard(
        title: 'Secundarios visibles',
        value:
            '${treatments.where((item) => item.id != selectedTreatment.id).length}',
        subtitle: 'Tratamientos adicionales del paciente',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 900;
        if (!twoColumns) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card,
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildClinicalColumn(
    BuildContext context,
    PatientTreatment selectedTreatment,
    List<PatientTreatment> treatments,
    List<StageHistoryEntry> history,
    String adminId,
  ) {
    return Column(
      children: [
        _PremiumPanel(
          title: 'Resumen clínico',
          subtitle:
              'Información clínica estructural del tratamiento visible y su contexto dentro del caso.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoGrid(
                items: [
                  _InfoCell(
                    label: 'Categoría',
                    value: PatientTreatment.labelForBaseTreatment(
                      selectedTreatment.categoria,
                    ),
                  ),
                  _InfoCell(
                    label: 'Tipo base',
                    value: PatientTreatment.labelForBaseTreatment(
                      selectedTreatment.tipoBase,
                    ),
                  ),
                  if (selectedTreatment.normalizedSubtypeLabel != null)
                    _InfoCell(
                      label: 'Subtipo',
                      value: selectedTreatment.normalizedSubtypeLabel!,
                    ),
                  _InfoCell(
                    label: 'Fecha de inicio',
                    value: _formatDate(selectedTreatment.fechaInicio),
                  ),
                  _InfoCell(
                    label: 'Estado',
                    value: selectedTreatment.statusLabel,
                  ),
                  _InfoCell(
                    label: 'Prioridad',
                    value: selectedTreatment.isPrimary
                        ? 'Principal'
                        : 'Secundario',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _NarrativeBlock(
                title: 'Notas clínicas',
                body: (selectedTreatment.notas ?? '').trim().isEmpty
                    ? 'Aún no hay notas clínicas registradas para este tratamiento.'
                    : selectedTreatment.notas!.trim(),
              ),
              const SizedBox(height: 14),
              _NarrativeBlock(
                title: 'Conexión operativa',
                body:
                    'Este tratamiento se conecta visualmente con pagos, citas, historial clínico y simulador del mismo paciente. El resumen financiero y el tracking de etapas se derivan del tratamiento seleccionado.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PremiumPanel(
          title: 'Etapas del tratamiento',
          subtitle:
              'Tracking clínico premium con foco en etapa activa, progreso y avance de etapa.',
          trailing: !selectedTreatment.id.startsWith('legacy-primary-')
              ? TextButton.icon(
                  onPressed: () => _openUpdateStageDialog(selectedTreatment),
                  icon: const Icon(Icons.track_changes_outlined),
                  label: const Text('Cambiar etapa'),
                )
              : null,
          child: TreatmentTimeline(
            etapaActual: selectedTreatment.etapaActual,
            historial: history,
            isAdmin: true,
            onAdvanceStage: selectedTreatment.id.startsWith('legacy-primary-')
                ? null
                : () => _openUpdateStageDialog(selectedTreatment),
          ),
        ),
        const SizedBox(height: 18),
        _PremiumPanel(
          title: 'Historial del tratamiento',
          subtitle:
              'Historial cronológico de cambios de etapa y acciones clínicas registradas.',
          child: StageHistoryList(historial: history, isAdmin: true),
        ),
        if (treatments
            .where((item) => item.id != selectedTreatment.id)
            .isNotEmpty) ...[
          const SizedBox(height: 18),
          _PremiumPanel(
            title: 'Tratamientos secundarios visibles',
            subtitle:
                'Los tratamientos adicionales del paciente se muestran separados, no absorbidos por el principal.',
            child: Column(
              children: treatments
                  .where((item) => item.id != selectedTreatment.id)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SecondaryTreatmentRow(
                        treatment: item,
                        currency: _currency,
                        onTap: () =>
                            setState(() => _selectedTreatmentId = item.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinancialColumn(
    BuildContext context,
    PatientTreatment selectedTreatment,
    TreatmentFinancialSummaryModel summary,
    List<FinancialItemModel> activeItems,
    List<FinancialItemModel> allItems,
    bool isSaving,
  ) {
    return Column(
      children: [
        _PremiumPanel(
          title: 'Resumen financiero',
          subtitle:
              'Resumen premium del tratamiento actual con claridad brutal en total, pagado y saldo.',
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F1EA),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE0D9CE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Monto total del tratamiento',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF908C88),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 8),
                        _AutocalculatedBadge(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currency.format(summary.totalAmount),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1208),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resultado directo de los conceptos activos configurados para este tratamiento. No depende de una cuenta global del paciente.',
                      style: TextStyle(
                        color: Color(0xFF908C88),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoGrid(
                items: [
                  _InfoCell(
                    label: 'Subtotal',
                    value: _currency.format(summary.subtotalAmount),
                  ),
                  _InfoCell(
                    label: 'Descuento',
                    value: _currency.format(summary.discountAmount),
                  ),
                  _InfoCell(
                    label: 'Pagado',
                    value: _currency.format(summary.paidAmount),
                  ),
                  _InfoCell(
                    label: 'Saldo',
                    value: _currency.format(summary.pendingAmount),
                  ),
                  _InfoCell(
                    label: 'Conceptos activos',
                    value: '${summary.itemsCount}',
                  ),
                  _InfoCell(
                    label: 'Última actualización',
                    value: _formatDate(
                      summary.lastPricingUpdateAt ?? DateTime.now(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PremiumPanel(
          title: 'Conceptos del tratamiento',
          subtitle:
              'Composición financiera premium del tratamiento con obligatorios, opcionales y fórmulas visibles.',
          trailing: !selectedTreatment.id.startsWith('legacy-primary-')
              ? TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ManageFinancialItemsDialog(
                      patientId: widget.patientId,
                      treatment: selectedTreatment,
                      initialItems: allItems,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar conceptos'),
                )
              : null,
          child: activeItems.isEmpty
              ? const OcgEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Aún no hay conceptos activos',
                  subtitle:
                      'Edita el tratamiento para construir el breakdown financiero premium.',
                )
              : Column(
                  children: activeItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ConceptPremiumRow(
                            item: item,
                            currency: _currency,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _PremiumPanel(
          title: 'Acciones del tratamiento',
          subtitle:
              'Operaciones principales del módulo en una superficie consistente y premium.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FooterActionButton(
                label: 'Editar tratamiento',
                icon: Icons.edit_outlined,
                filled: true,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ManagePatientTreatmentDialog(
                    patientId: widget.patientId,
                    patientName: widget.patient.nombre,
                    initialTreatment: selectedTreatment,
                  ),
                ),
              ),
              if (!selectedTreatment.id.startsWith('legacy-primary-'))
                _FooterActionButton(
                  label: 'Editar conceptos',
                  icon: Icons.account_balance_wallet_outlined,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ManageFinancialItemsDialog(
                      patientId: widget.patientId,
                      treatment: selectedTreatment,
                      initialItems: allItems,
                    ),
                  ),
                ),
              if (!selectedTreatment.isPrimary &&
                  !selectedTreatment.id.startsWith('legacy-primary-'))
                _FooterActionButton(
                  label: isSaving ? 'Guardando...' : 'Hacer principal',
                  icon: Icons.star_outline,
                  onPressed: isSaving
                      ? null
                      : () async {
                          await ref
                              .read(savePatientTreatmentProvider.notifier)
                              .setPrimaryTreatment(
                                patientId: widget.patientId,
                                treatment: selectedTreatment.copyWith(
                                  isPrimary: true,
                                ),
                              );
                        },
                ),
              if (!selectedTreatment.id.startsWith('legacy-primary-'))
                _FooterActionButton(
                  label: selectedTreatment.isFinished
                      ? 'Reactivar'
                      : 'Finalizar',
                  icon: selectedTreatment.isFinished
                      ? Icons.restart_alt_outlined
                      : Icons.task_alt_outlined,
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nextStatus = selectedTreatment.isFinished
                              ? 'activo'
                              : 'finalizado';
                          await ref
                              .read(savePatientTreatmentProvider.notifier)
                              .updateTreatmentStatus(
                                patientId: widget.patientId,
                                treatment: selectedTreatment,
                                newStatus: nextStatus,
                              );
                        },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openUpdateStageDialog(PatientTreatment treatment) {
    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? '';
    if (adminId.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => UpdateStageDialog(
        patientId: widget.patientId,
        treatmentId: treatment.id.startsWith('legacy-primary-')
            ? null
            : treatment.id,
        etapaActual: treatment.etapaActual,
        adminId: adminId,
      ),
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

  TreatmentFinancialSummaryModel _buildFinancialSummary(
    PatientTreatment treatment,
    List<FinancialItemModel> items,
  ) {
    final activeItems = items.where((item) => item.active).toList();
    if (activeItems.isEmpty) {
      final total = treatment.totalTratamiento ?? 0;
      final pending = treatment.saldoPendiente ?? total;
      final paid = (total - pending).clamp(0, double.infinity).toDouble();
      return TreatmentFinancialSummaryModel(
        currency: 'COP',
        subtotalAmount: total,
        discountAmount: 0,
        totalAmount: total,
        paidAmount: paid,
        pendingAmount: pending,
        itemsCount: 0,
        lastPricingUpdateAt: DateTime.now(),
      );
    }

    final total = activeItems.fold<double>(
      0,
      (sum, item) => sum + item.computedAmount,
    );
    final pending = treatment.saldoPendiente ?? total;
    final paid = (total - pending).clamp(0, double.infinity).toDouble();

    return TreatmentFinancialSummaryModel(
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0,
      totalAmount: total,
      paidAmount: paid,
      pendingAmount: pending,
      itemsCount: activeItems.length,
      lastPricingUpdateAt: DateTime.now(),
    );
  }

  int _stageProgress(TreatmentStage stage) {
    final index = TreatmentStage.values.indexOf(stage);
    if (index <= 0) return 8;
    final progress = (((index + 1) / TreatmentStage.values.length) * 100)
        .round();
    return progress.clamp(8, 100);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8DED2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0D0A07),
            blurRadius: 22,
            offset: Offset(0, 12),
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
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1208),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF908C88),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MetricHeroCard extends StatelessWidget {
  const _MetricHeroCard({
    required this.label,
    required this.value,
    required this.supporting,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final String supporting;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF5F1EA) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFE0D9CE)
              : const Color(0xFFEDE7DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF908C88),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: highlighted ? const Color(0xFF1A1208) : OcgColors.espresso,
              fontWeight: FontWeight.w700,
              fontSize: highlighted ? 24 : 19,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            supporting,
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.icon,
    required this.label,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? OcgColors.ivory : const Color(0xFF5C5550);
    return SizedBox(
      height: 42,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5E25),
                foregroundColor: foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: const BorderSide(color: Color(0xFFE0D9CE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }
}

class _TreatmentStreamCard extends StatelessWidget {
  const _TreatmentStreamCard({
    super.key,
    required this.treatment,
    required this.selected,
    required this.currency,
    required this.onTap,
  });

  final PatientTreatment treatment;
  final bool selected;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paid =
        ((treatment.totalTratamiento ?? 0) - (treatment.saldoPendiente ?? 0))
            .clamp(0, double.infinity)
            .toDouble();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F1EA) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFFB07D3C) : const Color(0xFFE8DED2),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x100D0A07),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    treatment.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1208),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (treatment.isPrimary)
                  const Icon(Icons.star, size: 16, color: Color(0xFFB07D3C)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              PatientTreatment.labelForBaseTreatment(treatment.tipoBase),
              style: const TextStyle(
                color: Color(0xFF908C88),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TinyPill(label: treatment.statusLabel),
                _TinyPill(
                  label:
                      stageNames[treatment.etapaActual] ??
                      treatment.etapaActual.name,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Saldo ${currency.format(treatment.saldoPendiente ?? 0)}',
              style: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Pagado ${currency.format(paid)}',
              style: const TextStyle(
                color: Color(0xFF8A6F59),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactInsightCard extends StatelessWidget {
  const _CompactInsightCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF908C88),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1208),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoCell> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 640 ? 1 : 2;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(width: width, child: item))
              .toList(),
        );
      },
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE7DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF908C88),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1208),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  const _NarrativeBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE7DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A1208),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF6D6258),
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryTreatmentRow extends StatelessWidget {
  const _SecondaryTreatmentRow({
    required this.treatment,
    required this.currency,
    required this.onTap,
  });

  final PatientTreatment treatment;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDE7DC)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    treatment.displayName,
                    style: const TextStyle(
                      color: Color(0xFF1A1208),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${PatientTreatment.labelForBaseTreatment(treatment.tipoBase)} · ${stageNames[treatment.etapaActual] ?? treatment.etapaActual.name}',
                    style: const TextStyle(
                      color: Color(0xFF8A6F59),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              currency.format(treatment.saldoPendiente ?? 0),
              style: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptPremiumRow extends StatelessWidget {
  const _ConceptPremiumRow({required this.item, required this.currency});

  final FinancialItemModel item;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final supportsQuantity = item.kind == 'controls';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE7DC)),
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
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF2C2420),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (supportsQuantity)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${currency.format(item.effectiveUnitAmount)} × ${item.effectiveQuantity}',
                          style: const TextStyle(
                            color: Color(0xFF908C88),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${currency.format(item.computedAmount)} COP',
                style: const TextStyle(
                  color: Color(0xFF1A1208),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyPill(label: item.isRequired ? 'Obligatorio' : 'Opcional'),
              _TinyPill(label: item.active ? 'Activo' : 'Inactivo'),
              _TinyPill(label: 'Orden ${item.order}'),
            ],
          ),
          if (item.isRequired) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Este concepto forma parte de la estructura base del tratamiento y no debe quedar vacío.',
                style: TextStyle(
                  color: Color(0xFF908C88),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterActionButton extends StatelessWidget {
  const _FooterActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5E25),
                foregroundColor: OcgColors.ivory,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5C5550),
                side: const BorderSide(color: Color(0xFFE0D9CE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5C5550),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AutocalculatedBadge extends StatelessWidget {
  const _AutocalculatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Autocalculado',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF908C88),
        ),
      ),
    );
  }
}
