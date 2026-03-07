import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_card.dart';
import '../../data/models/patient_model.dart';

class PatientSimulatorTab extends StatelessWidget {
  const PatientSimulatorTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OcgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simulador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Paciente: ${patient.nombre}'),
              const SizedBox(height: 4),
              const Text('Acceso e historial de simulaciones: siguiente iteración del bloque activo.'),
            ],
          ),
        ),
      ],
    );
  }
}
