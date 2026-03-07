import 'package:flutter/material.dart';

import '../../../../shared/widgets/ocg_card.dart';
import '../../data/models/patient_model.dart';

class PatientProfileTab extends StatelessWidget {
  const PatientProfileTab({super.key, required this.patient});

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
              const Text('Datos personales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _Field(label: 'Nombre', value: patient.nombre),
              _Field(label: 'Correo', value: patient.email),
              _Field(label: 'Teléfono', value: patient.telefono),
              _Field(label: 'Fecha nacimiento', value: _fmt(patient.fechaNacimiento)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OcgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Datos clínicos (solo admin)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _Field(label: 'Tipo de tratamiento', value: patient.tipoTratamiento.name),
              _Field(label: 'Etapa actual', value: patient.etapaActual.name),
              _Field(label: 'Fecha inicio', value: _fmt(patient.fechaInicio)),
              _Field(label: 'Fecha estimada fin', value: patient.fechaEstimadaFin == null ? 'No definida' : _fmt(patient.fechaEstimadaFin!)),
              _Field(label: 'Notas clínicas', value: patient.notasClinicas.isEmpty ? 'Sin notas' : patient.notasClinicas),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
