import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientTreatmentTab extends StatelessWidget {
  const PatientTreatmentTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: OcgEmptyState(
        icon: Icons.timeline_outlined,
        title: 'Tratamiento en preparación',
        subtitle: 'Tu doctora actualizará tu plan de tratamiento pronto.',
      ),
    );
  }
}
