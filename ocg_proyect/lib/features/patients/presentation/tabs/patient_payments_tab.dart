import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../data/models/patient_model.dart';

class PatientPaymentsTab extends StatelessWidget {
  const PatientPaymentsTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: OcgEmptyState(
        icon: Icons.payment_outlined,
        title: 'Pagos',
        subtitle: 'El historial de pagos estará disponible próximamente.',
      ),
    );
  }
}
