import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientSimulatorTab extends StatelessWidget {
  const PatientSimulatorTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: OcgEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Simulador de sonrisa',
        subtitle: 'El simulador estará disponible próximamente.',
      ),
    );
  }
}
