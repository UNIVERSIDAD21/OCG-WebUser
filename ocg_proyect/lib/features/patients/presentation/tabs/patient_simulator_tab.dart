import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../features/simulator/presentation/simulator_screen.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientSimulatorTab extends ConsumerWidget {
  const PatientSimulatorTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminId = ref.watch(authStateProvider).asData?.value?.uid ?? '';

    if (adminId.isEmpty) {
      return const Center(
        child: OcgEmptyState(
          icon: Icons.lock_outline,
          title: 'Sesión no disponible',
          subtitle: 'Inicia sesión nuevamente para usar el simulador.',
        ),
      );
    }

    return SimulatorScreen(
      patientId: patient.id,
      adminId: adminId,
      treatmentType: patient.tipoTratamiento,
    );
  }
}
