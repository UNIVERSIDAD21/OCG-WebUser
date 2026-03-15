import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../treatment/presentation/widgets/stage_history_list.dart';
import '../../../treatment/presentation/widgets/treatment_timeline.dart';
import '../../../treatment/presentation/widgets/update_stage_dialog.dart';
import '../../../treatment/providers/treatment_provider.dart';
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
            TreatmentTimeline(
              etapaActual: patient.etapaActual,
              historial: historial,
              isAdmin: true,
              onAdvanceStage: patient.etapaActual == TreatmentStage.alta
                  ? null
                  : () => showDialog<void>(
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
            StageHistoryList(historial: historial),
          ],
        ),
      ),
    );
  }
}
