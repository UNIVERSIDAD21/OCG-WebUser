import 'package:flutter/material.dart';

import '../../../patients/data/models/patient_model.dart';
import '../../../../shared/theme/ocg_colors.dart';

class TreatmentProgressBar extends StatelessWidget {
  const TreatmentProgressBar({super.key, required this.etapaActual});

  final TreatmentStage etapaActual;

  @override
  Widget build(BuildContext context) {
    final index = TreatmentStage.values.indexOf(etapaActual);
    final progress = index / (TreatmentStage.values.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etapa ${index + 1} de ${TreatmentStage.values.length} — ${stageNames[etapaActual] ?? etapaActual.name}'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            color: OcgColors.bronze,
            backgroundColor: const Color(0xFFE8E1D9),
          ),
        ),
      ],
    );
  }
}
