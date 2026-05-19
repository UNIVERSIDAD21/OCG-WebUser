import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_skeleton.dart';
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
import '../../../treatment/providers/patient_treatments_provider.dart';
import '../../../treatment/providers/treatment_provider.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../appointments/domain/appointments_business_rules.dart';
import '../../data/models/patient_data_resolution.dart';
import '../../data/models/patient_model.dart';

class PatientTreatmentTab extends ConsumerStatefulWidget {
  const PatientTreatmentTab({
    super.key,
    required this.patientId,
    required this.patient,
    this.scrollable = true,
    this.initialTreatmentId,
    this.focusHistory = false,
  });

  final String patientId;
  final PatientModel patient;
  final bool scrollable;
  final String? initialTreatmentId;
  final bool focusHistory;

  @override
  ConsumerState<PatientTreatmentTab> createState() =>
      _PatientTreatmentTabState();
}

const String _kHistoryAllTreatments = '__all_treatment_history__';

class _PatientTreatmentTabState extends ConsumerState<PatientTreatmentTab> {
  String? _selectedTreatmentId;
  String? _historyTreatmentFilterId;
  bool _legacyMigrationQueued = false;
  String? _ensuredFinancialItemsForTreatmentId;
  bool _historyFocusPending = false;
  final GlobalKey _historySectionKey = GlobalKey();

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _selectedTreatmentId = _cleanTreatmentId(widget.initialTreatmentId);
    _historyTreatmentFilterId = _selectedTreatmentId;
    _historyFocusPending = widget.focusHistory;
  }

  @override
  void didUpdateWidget(covariant PatientTreatmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _selectedTreatmentId = _cleanTreatmentId(widget.initialTreatmentId);
      _historyTreatmentFilterId = _selectedTreatmentId;
      _legacyMigrationQueued = false;
      _ensuredFinancialItemsForTreatmentId = null;
    }
    if (oldWidget.initialTreatmentId != widget.initialTreatmentId) {
      _selectedTreatmentId = _cleanTreatmentId(widget.initialTreatmentId);
      _historyTreatmentFilterId = _selectedTreatmentId;
    }
    if (oldWidget.focusHistory != widget.focusHistory ||
        oldWidget.initialTreatmentId != widget.initialTreatmentId) {
      _historyFocusPending = widget.focusHistory;
    }
  }

  String? _cleanTreatmentId(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean;
  }

  void _scheduleHistoryFocusIfNeeded() {
    if (!_historyFocusPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _historySectionKey.currentContext;
      if (targetContext == null) return;
      _historyFocusPending = false;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _selectTreatment(PatientTreatment treatment) {
    setState(() {
      _selectedTreatmentId = treatment.id;
      if (_historyTreatmentFilterId != _kHistoryAllTreatments) {
        _historyTreatmentFilterId = treatment.id;
      }
    });
  }

  void _openTreatmentHistory(PatientTreatment treatment) {
    context.go(_patientTreatmentHistoryLocation(treatment.id));
  }

  String _patientTreatmentHistoryLocation(String treatmentId) {
    final path = RouteNames.adminPatientDetail.replaceFirst(
      ':patientId',
      widget.patientId,
    );
    return Uri(
      path: path,
      queryParameters: <String, String>{
        'section': 'tratamientos',
        'treatmentId': treatmentId,
        'focus': 'history',
      },
    ).toString();
  }

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

    final hasSingleLegacyTreatment =
        treatments.length == 1 &&
        treatments.first.id.startsWith('legacy-primary-');

    if (!hasSingleLegacyTreatment) {
      _legacyMigrationQueued = false;
    } else if (!_legacyMigrationQueued && !saveState.isLoading) {
      _legacyMigrationQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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
    final isLegacySelected = selectedTreatment.id.startsWith('legacy-primary-');
    if (isLegacySelected) {
      _ensuredFinancialItemsForTreatmentId = null;
    } else if (_ensuredFinancialItemsForTreatmentId != selectedTreatment.id) {
      _ensuredFinancialItemsForTreatmentId = selectedTreatment.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(ensureTreatmentFinancialItemsProvider)(
          widget.patientId,
          selectedTreatment,
        );
      });
    }

    if (saveState.hasError && hasSingleLegacyTreatment) {
      return _buildMigrationErrorState(context, saveState.error);
    }

    final financialItemsAsync = isLegacySelected
        ? const AsyncValue<List<FinancialItemModel>>.data(
            <FinancialItemModel>[],
          )
        : ref.watch(
            treatmentFinancialItemsProvider((
              patientId: widget.patientId,
              treatmentId: selectedTreatment.id,
            )),
          );

    final historyAsync = isLegacySelected
        ? ref.watch(stageHistoryProvider(widget.patientId))
        : ref.watch(
            treatmentStageHistoryProvider((
              patientId: widget.patientId,
              treatmentId: selectedTreatment.id,
            )),
          );
    final treatmentIdsKey = (treatments.map((t) => t.id).toList()..sort()).join(
      '|',
    );
    final allHistoryAsync = ref.watch(
      allTreatmentStageHistoryProvider((
        patientId: widget.patientId,
        treatmentIdsKey: treatmentIdsKey,
      )),
    );

    final adminId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    return financialItemsAsync.when(
      loading: () => const OcgSkeletonList(items: 3, cardHeight: 138),
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
          loading: () => const OcgSkeletonList(items: 3, cardHeight: 138),
          error: (error, _) => Center(
            child: OcgEmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar el historial de etapas',
              subtitle: '$error',
            ),
          ),
          data: (history) {
            return allHistoryAsync.when(
              loading: () => const OcgSkeletonList(items: 3, cardHeight: 138),
              error: (error, _) => Center(
                child: OcgEmptyState(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar el historial consolidado',
                  subtitle: '$error',
                ),
              ),
              data: (allHistory) {
                _scheduleHistoryFocusIfNeeded();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;
                    if (isMobile) {
                      return _buildMobileTreatmentView(
                        context,
                        selectedTreatment,
                        summary,
                        activeItems,
                        history,
                        allHistory,
                        saveState.isLoading,
                        treatments,
                      );
                    }

                    final content = Padding(
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
                          _buildSummaryGrid(
                            selectedTreatment,
                            treatments,
                            summary,
                          ),
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
                                      allHistory,
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
                                      allHistory,
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
                    );

                    // En el branch de escritorio (dentro de TabBarView) siempre se
                    // necesita scroll propio: el TabBarView da altura ACOTADA y el
                    // contenido puede superar ese límite. El branch móvil ya retornó
                    // arriba, así que aquí nunca hay riesgo de scroll anidado.
                    return SingleChildScrollView(child: content);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileTreatmentView(
    BuildContext context,
    PatientTreatment selectedTreatment,
    TreatmentFinancialSummaryModel summary,
    List<FinancialItemModel> activeItems,
    List<StageHistoryEntry> history,
    List<StageHistoryEntry> allHistory,
    bool isSaving,
    List<PatientTreatment> treatments,
  ) {
    final stageLabel =
        stageNames[selectedTreatment.etapaActual] ??
        selectedTreatment.etapaActual.name;
    final latestHistory = history.isEmpty ? null : history.first;
    final historyFilterId = _resolvedHistoryFilterId(
      selectedTreatment,
      treatments,
    );
    final displayedHistory = _historyForFilter(
      filterId: historyFilterId,
      selectedTreatment: selectedTreatment,
      selectedHistory: history,
      allHistory: allHistory,
    );
    final visibleItems = activeItems.take(3).toList();
    final hasMoreItems = activeItems.length > visibleItems.length;
    final latestNote = (selectedTreatment.notas ?? '').trim();
    final statusColor = _treatmentStatusColor(selectedTreatment);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de tratamiento (solo si hay más de 1)
          if (treatments.length > 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OcgColors.mist,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OcgColors.espresso.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tratamiento',
                    style: TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTreatment.id,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: OcgColors.bronze,
                      ),
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      items: treatments.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.id,
                          child: Text(
                            '${t.displayName}${t.isPrimary ? ' (Principal)' : ''}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final newTreatment = treatments.firstWhere(
                            (t) => t.id == value,
                            orElse: () => selectedTreatment,
                          );
                          _selectTreatment(newTreatment);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _buildMobileTreatmentCard(
            title: 'Estado del tratamiento',
            icon: Icons.monitor_heart_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _StatusDot(color: statusColor, size: 10),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _buildMobileTreatmentName(
                        selectedTreatment,
                        stageLabel: stageLabel,
                        statusColor: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _mobileInfoRow('Estado', selectedTreatment.statusLabel),
                _mobileInfoRow('Etapa actual', stageLabel),
                _mobileInfoRow(
                  'Progreso',
                  '${_stageProgress(selectedTreatment.etapaActual)}%',
                ),
                _mobileInfoRow(
                  'Fecha de inicio',
                  _formatDate(selectedTreatment.fechaInicio),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildMobileTreatmentCard(
            title: 'Resumen financiero del tratamiento',
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mobileInfoRow(
                  'Valor total',
                  _currency.format(summary.totalAmount),
                ),
                _mobileInfoRow(
                  'Total pagado',
                  _currency.format(summary.paidAmount),
                ),
                _mobileInfoRow(
                  'Saldo pendiente',
                  _currency.format(summary.pendingAmount),
                ),
                _mobileInfoRow(
                  'Próximo pago',
                  widget.patient.fechaProximoPago == null
                      ? 'Sin fecha programada'
                      : _formatDate(widget.patient.fechaProximoPago!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildMobileTreatmentCard(
            title: 'Conceptos del tratamiento',
            icon: Icons.receipt_long_outlined,
            child: activeItems.isEmpty
                ? const Text(
                    'No hay conceptos registrados para este tratamiento.',
                    style: TextStyle(color: OcgColors.bronze),
                  )
                : Column(
                    children: [
                      for (final item in visibleItems)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F3ED),
                            borderRadius: BorderRadius.circular(14),
                          ),
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
                              const SizedBox(height: 6),
                              Text(
                                _currency.format(item.computedAmount),
                                style: const TextStyle(color: OcgColors.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.active ? 'Activo' : 'Pendiente',
                                style: const TextStyle(color: OcgColors.bronze),
                              ),
                            ],
                          ),
                        ),
                      if (hasMoreItems)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Ver todos'),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _buildMobileTreatmentCard(
            title: 'Notas clínicas',
            icon: Icons.notes_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latestNote.isEmpty
                      ? 'No hay notas clínicas registradas.'
                      : latestNote,
                  style: const TextStyle(color: OcgColors.ink),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  latestHistory == null
                      ? 'Sin historial reciente.'
                      : 'Último movimiento: ${_formatDate(latestHistory.fechaCambio)}',
                  style: const TextStyle(color: OcgColors.bronze),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildMobileTreatmentCard(
            key: _historySectionKey,
            title: 'Historial del tratamiento',
            icon: Icons.history_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTreatmentHistoryFilter(
                  selectedTreatment: selectedTreatment,
                  treatments: treatments,
                  displayedHistory: displayedHistory,
                ),
                const SizedBox(height: 12),
                StageHistoryList(historial: displayedHistory, isAdmin: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildMobileTreatmentCard(
            title: 'Acciones',
            icon: Icons.flash_on_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => ManagePatientTreatmentDialog(
                          patientId: widget.patientId,
                          patientName: widget.patient.nombre,
                          initialTreatment: selectedTreatment,
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Ver tratamiento completo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openTreatmentHistory(selectedTreatment),
                      icon: const Icon(Icons.history_outlined, size: 18),
                      label: const Text('Ver historial clínico'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'La nota rápida se habilitará en un bloque posterior. Usa escritorio para edición clínica completa.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: const Text('Agregar nota'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ve a la ficha del paciente y abre Pagos para el detalle completo.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Ir a pagos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para edición completa del tratamiento, usa la versión de escritorio.',
                  style: TextStyle(
                    color: OcgColors.bronze,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.scrollable) return content;
    return SingleChildScrollView(child: content);
  }

  Widget _buildMobileTreatmentName(
    PatientTreatment treatment, {
    required String stageLabel,
    required Color statusColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showTreatmentNameSheet(
        treatment,
        stageLabel: stageLabel,
        statusColor: statusColor,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Text(
          treatment.displayName,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: OcgColors.espresso,
          ),
        ),
      ),
    );
  }

  void _showTreatmentNameSheet(
    PatientTreatment treatment, {
    required String stageLabel,
    required Color statusColor,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: OcgColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _StatusDot(color: statusColor, size: 10),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        treatment.displayName,
                        style: const TextStyle(
                          color: OcgColors.espresso,
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _mobileInfoRow('Estado', treatment.statusLabel),
                _mobileInfoRow('Etapa actual', stageLabel),
                _mobileInfoRow(
                  'Tipo',
                  PatientTreatment.labelForBaseTreatment(treatment.tipoBase),
                ),
                if (treatment.normalizedSubtypeLabel != null)
                  _mobileInfoRow('Subtipo', treatment.normalizedSubtypeLabel!),
                _mobileInfoRow('Inicio', _formatDate(treatment.fechaInicio)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileTreatmentCard({
    Key? key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: OcgColors.espresso),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _mobileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: OcgColors.bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: OcgColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationErrorState(BuildContext context, Object? error) {
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
          icon: Icons.error_outline,
          title: 'No se pudo preparar el tratamiento legacy del paciente',
          subtitle:
              'El detalle sigue disponible, pero la migración automática falló para este paciente. Error: $error',
          ctaLabel: 'Reintentar migración',
          onCta: () {
            setState(() => _legacyMigrationQueued = false);
          },
        ),
      ),
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
                    icon: Icons.add_circle_outline,
                    label: 'Nuevo tratamiento',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ManagePatientTreatmentDialog(
                        patientId: widget.patientId,
                        patientName: widget.patient.nombre,
                      ),
                    ),
                  ),
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
                  _HeroActionButton(
                    icon: Icons.history_outlined,
                    label: 'Ver historial clínico',
                    onPressed: () => _openTreatmentHistory(selectedTreatment),
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
                _TreatmentScheduleCard(
                  patientId: widget.patientId,
                  patientName: widget.patient.nombre,
                  treatment: selectedTreatment,
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
                  onTap: () => _selectTreatment(treatment),
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

  String _resolvedHistoryFilterId(
    PatientTreatment selectedTreatment,
    List<PatientTreatment> treatments,
  ) {
    final ids = treatments.map((t) => t.id).toSet();
    final current = _historyTreatmentFilterId;
    if (current == _kHistoryAllTreatments) return _kHistoryAllTreatments;
    if (current != null && ids.contains(current)) return current;
    return selectedTreatment.id;
  }

  List<StageHistoryEntry> _historyForFilter({
    required String filterId,
    required PatientTreatment selectedTreatment,
    required List<StageHistoryEntry> selectedHistory,
    required List<StageHistoryEntry> allHistory,
  }) {
    if (filterId == _kHistoryAllTreatments) return allHistory;
    if (filterId == selectedTreatment.id) return selectedHistory;
    return allHistory.where((entry) => entry.treatmentId == filterId).toList();
  }

  Widget _buildTreatmentHistoryFilter({
    required PatientTreatment selectedTreatment,
    required List<PatientTreatment> treatments,
    required List<StageHistoryEntry> displayedHistory,
  }) {
    final filterId = _resolvedHistoryFilterId(selectedTreatment, treatments);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OcgColors.espresso.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.filter_alt_outlined,
                  color: OcgColors.espresso,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar historial',
                      style: TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${displayedHistory.length} movimiento${displayedHistory.length == 1 ? '' : 's'} visible${displayedHistory.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: OcgColors.ink.withOpacity(0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  selected: filterId == _kHistoryAllTreatments,
                  avatar: Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: filterId == _kHistoryAllTreatments
                        ? OcgColors.ivory
                        : OcgColors.espresso,
                  ),
                  label: const Text('Todos'),
                  selectedColor: OcgColors.espresso,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: filterId == _kHistoryAllTreatments
                        ? OcgColors.ivory
                        : OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: filterId == _kHistoryAllTreatments
                        ? OcgColors.espresso
                        : OcgColors.bronze.withOpacity(0.24),
                  ),
                  onSelected: (_) => setState(
                    () => _historyTreatmentFilterId = _kHistoryAllTreatments,
                  ),
                ),
                const SizedBox(width: 8),
                for (final treatment in treatments) ...[
                  ChoiceChip(
                    selected: filterId == treatment.id,
                    avatar: Icon(
                      treatment.id == selectedTreatment.id
                          ? Icons.radio_button_checked
                          : Icons.monitor_heart_outlined,
                      size: 16,
                      color: filterId == treatment.id
                          ? OcgColors.ivory
                          : OcgColors.espresso,
                    ),
                    label: Text(treatment.displayName),
                    selectedColor: OcgColors.bronze,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: filterId == treatment.id
                          ? OcgColors.ivory
                          : OcgColors.espresso,
                      fontWeight: FontWeight.w800,
                    ),
                    side: BorderSide(
                      color: filterId == treatment.id
                          ? OcgColors.bronze
                          : OcgColors.bronze.withOpacity(0.24),
                    ),
                    onSelected: (_) => setState(
                      () => _historyTreatmentFilterId = treatment.id,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalColumn(
    BuildContext context,
    PatientTreatment selectedTreatment,
    List<PatientTreatment> treatments,
    List<StageHistoryEntry> history,
    List<StageHistoryEntry> allHistory,
    String adminId,
  ) {
    final historyFilterId = _resolvedHistoryFilterId(
      selectedTreatment,
      treatments,
    );
    final displayedHistory = _historyForFilter(
      filterId: historyFilterId,
      selectedTreatment: selectedTreatment,
      selectedHistory: history,
      allHistory: allHistory,
    );

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
          key: _historySectionKey,
          title: 'Historial del tratamiento',
          subtitle:
              'Historial cronológico de cambios de etapa y acciones clínicas registradas.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTreatmentHistoryFilter(
                selectedTreatment: selectedTreatment,
                treatments: treatments,
                displayedHistory: displayedHistory,
              ),
              const SizedBox(height: 14),
              StageHistoryList(historial: displayedHistory, isAdmin: true),
            ],
          ),
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
                        onTap: () => _selectTreatment(item),
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
    final patient = widget.patient;
    // En vez del diálogo "Avanzar etapa", abrimos el Dictamen (ConsultationScreen)
    // Creamos una cita sintética con los datos del paciente para la navegación.
    final syntheticAppt = AppointmentModel(
      id: 'dictamen-${patient.id}-${DateTime.now().millisecondsSinceEpoch}',
      patientId: patient.id,
      patientName: patient.nombre,
      patientPhone: patient.telefono,
      treatmentId: treatment.id.startsWith('legacy-primary-')
          ? null
          : treatment.id,
      treatmentNameSnapshot: treatment.displayName,
      tipo: AppointmentsBusinessRules.appointmentTypeForStage(
        treatment.etapaActual,
      ),
      estado: AppointmentStatus.programada,
      fechaHora: DateTime.now(),
      duracionMinutos: 30,
      creadoPor: ref.read(authStateProvider).asData?.value?.uid ?? 'admin',
      stageId: treatment.etapaActual,
      stageNameSnapshot:
          stageNames[treatment.etapaActual] ?? treatment.etapaActual.name,
    );
    context.push(RouteNames.adminConsultation, extra: syntheticAppt);
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
    super.key,
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

class _TreatmentScheduleCard extends ConsumerWidget {
  const _TreatmentScheduleCard({
    required this.patientId,
    required this.patientName,
    required this.treatment,
  });

  final String patientId;
  final String patientName;
  final PatientTreatment treatment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const Text(
            'Frecuencia de control',
            style: TextStyle(
              color: Color(0xFF908C88),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cada ${treatment.suggestedControlEveryMonths} meses',
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
              fontSize: 19,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Limpieza cada ${treatment.suggestedCleaningEveryMonths} meses',
            style: const TextStyle(
              color: Color(0xFF8A6F59),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTag(
                icon: Icons.event_repeat_outlined,
                label: treatment.nextControlDate == null
                    ? 'Control sin fecha'
                    : 'Control ${_fmtDate(treatment.nextControlDate!)}',
                accent: OcgColors.espresso,
                background: const Color(0xFFF5F1EA),
              ),
              _HeroTag(
                icon: Icons.cleaning_services_outlined,
                label: treatment.nextCleaningDate == null
                    ? 'Limpieza sin fecha'
                    : 'Limpieza ${_fmtDate(treatment.nextCleaningDate!)}',
                accent: OcgColors.espresso,
                background: const Color(0xFFF5F1EA),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ManagePatientTreatmentDialog(
                patientId: patientId,
                patientName: patientName,
                initialTreatment: treatment,
              ),
            ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Editar fechas'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

Color _treatmentStatusColor(PatientTreatment treatment) {
  return switch (treatment.estado.trim().toLowerCase()) {
    'activo' => OcgColors.success,
    'pausado' => OcgColors.warning,
    'finalizado' => const Color(0xFF1B45A0),
    'cancelado' => OcgColors.error,
    _ => OcgColors.bronze,
  };
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
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
    final statusColor = _treatmentStatusColor(treatment);
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
            color: selected ? statusColor : statusColor.withValues(alpha: 0.24),
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
                _StatusDot(color: statusColor),
                const SizedBox(width: 8),
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
