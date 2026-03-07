import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_card.dart';
import '../../data/models/patient_model.dart';

class PatientTreatmentTab extends StatelessWidget {
  const PatientTreatmentTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    final timeline = [
      TreatmentStage.diagnostico,
      TreatmentStage.planificacion,
      TreatmentStage.instalacion,
      TreatmentStage.seguimientoActivo,
      TreatmentStage.ajusteFinal,
      TreatmentStage.retencion,
      TreatmentStage.alta,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OcgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Etapa actual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(patient.etapaActual.name),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OcgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Timeline del tratamiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...timeline.map((stage) {
                final isCurrent = stage == patient.etapaActual;
                final isReached = stage.index <= patient.etapaActual.index;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCurrent ? Icons.radio_button_checked : (isReached ? Icons.check_circle : Icons.radio_button_unchecked),
                  ),
                  title: Text(stage.name),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
