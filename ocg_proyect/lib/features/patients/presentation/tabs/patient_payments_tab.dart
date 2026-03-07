import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_card.dart';
import '../../data/models/patient_model.dart';

class PatientPaymentsTab extends StatelessWidget {
  const PatientPaymentsTab({super.key, required this.patient});

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
              const Text('Pagos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Total tratamiento: ${patient.totalTratamiento.toStringAsFixed(0)} COP'),
              Text('Saldo pendiente: ${patient.saldoPendiente.toStringAsFixed(0)} COP'),
              const SizedBox(height: 6),
              const Text('Detalle de transacciones: siguiente iteración del bloque activo.'),
            ],
          ),
        ),
      ],
    );
  }
}
