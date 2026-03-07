import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../../shared/widgets/ocg_card.dart';
import '../providers/patients_provider.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: const Center(child: Text('Debes iniciar sesión para ver tu perfil.')),
      );
    }

    final patientAsync = ref.watch(patientByIdProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'No se pudo cargar tu perfil: $error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (patient) {
          if (patient == null) {
            return const Center(
              child: Text(
                'No encontramos tu registro clínico aún.\nSolicita activación en recepción/admin.',
                textAlign: TextAlign.center,
              ),
            );
          }

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
                    const Text('Resumen clínico (solo lectura)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _Field(label: 'Tipo tratamiento', value: patient.tipoTratamiento.name),
                    _Field(label: 'Etapa actual', value: patient.etapaActual.name),
                    _Field(label: 'Fecha inicio', value: _fmt(patient.fechaInicio)),
                    _Field(label: 'Fecha estimada fin', value: patient.fechaEstimadaFin == null ? 'No definida' : _fmt(patient.fechaEstimadaFin!)),
                    _Field(label: 'Notas clínicas', value: patient.notasClinicas.isEmpty ? 'Sin notas' : patient.notasClinicas),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OcgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estado financiero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _Field(label: 'Total tratamiento', value: '${patient.totalTratamiento.toStringAsFixed(0)} COP'),
                    _Field(label: 'Saldo pendiente', value: '${patient.saldoPendiente.toStringAsFixed(0)} COP'),
                    _Field(
                      label: 'Próximo pago',
                      value: patient.fechaProximoPago == null ? 'No definido' : _fmt(patient.fechaProximoPago!),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
