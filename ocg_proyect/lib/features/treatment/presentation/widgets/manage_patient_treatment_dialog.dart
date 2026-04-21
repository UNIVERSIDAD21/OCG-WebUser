import 'package:flutter/material.dart';

import '../../data/models/patient_treatment.dart';

class ManagePatientTreatmentDialog extends StatelessWidget {
  const ManagePatientTreatmentDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.initialTreatment,
  });

  final String patientId;
  final String patientName;
  final PatientTreatment? initialTreatment;

  @override
  Widget build(BuildContext context) {
    final editing = initialTreatment != null;
    return AlertDialog(
      title: Text(editing ? 'Editar tratamiento' : 'Crear tratamiento'),
      content: Text(
        editing
            ? 'El editor completo de tratamientos no está disponible en este diálogo todavía para $patientName.'
            : 'La creación guiada de tratamientos no está disponible en este diálogo todavía para $patientName.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
