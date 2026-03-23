import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../treatment/presentation/widgets/stage_history_list.dart';
import '../../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../../treatment/presentation/widgets/update_stage_dialog.dart';
import '../../../treatment/providers/treatment_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientTreatmentTab extends ConsumerWidget {
  const PatientTreatmentTab({
    super.key,
    required this.patientId,
    required this.patient,
  });

  final String patientId;
  final PatientModel patient;

  String _labelTipoTratamiento(TreatmentType type) {
    switch (type) {
      case TreatmentType.convencional:
        return 'Convencional';
      case TreatmentType.estetico:
        return 'Estético';
      case TreatmentType.autoligado:
        return 'Autoligado';
      case TreatmentType.alineadores:
        return 'Alineadores';
      case TreatmentType.ortopedia:
        return 'Ortopedia';
      case TreatmentType.interceptivo:
        return 'Interceptivo';
      case TreatmentType.retenedores:
        return 'Retenedores';
    }
  }

  String _formatCop(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      final posFromEnd = value.length - i;
      buffer.write(value[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return '\$${buffer.toString()} COP';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(stageHistoryProvider(patientId));
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
            if (patient.tipoTratamiento != null && patient.totalTratamiento > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OcgColors.success.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: OcgColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Definido en valoración inicial · ${_labelTipoTratamiento(patient.tipoTratamiento!)} · '
                        'Monto: ${_formatCop(patient.totalTratamiento)}',
                        style: const TextStyle(
                          color: OcgColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TreatmentTimeline(
              etapaActual: patient.etapaActual,
              historial: historial,
              isAdmin: true,
              onAdvanceStage: () => showDialog<void>(
                    context: context,
                    builder: (_) => UpdateStageDialog(
                      patientId: patientId,
                      etapaActual: patient.etapaActual,
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
}
