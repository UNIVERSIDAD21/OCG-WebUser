import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
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
