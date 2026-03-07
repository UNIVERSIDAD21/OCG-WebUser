import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../data/models/patient_model.dart';
import '../providers/patients_provider.dart';
import 'tabs/patient_appointments_tab.dart';
import 'tabs/patient_payments_tab.dart';
import 'tabs/patient_profile_tab.dart';
import 'tabs/patient_simulator_tab.dart';
import 'tabs/patient_treatment_tab.dart';

class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientByIdProvider(patientId));

    return patientAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Detalle de paciente')),
        body: Center(
          child: Text(
            'No se pudo cargar el paciente: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de paciente')),
            body: const Center(child: Text('Paciente no encontrado.')),
          );
        }

        return _PatientDetailView(patient: patient);
      },
    );
  }
}

class _PatientDetailView extends StatelessWidget {
  const _PatientDetailView({required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient.nombre),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Perfil'),
              Tab(text: 'Tratamiento'),
              Tab(text: 'Citas'),
              Tab(text: 'Pagos'),
              Tab(text: 'Simulador'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              color: OcgColors.mist,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OcgChip(label: patient.tipoTratamiento.name),
                  OcgChip(label: patient.etapaActual.name),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PatientProfileTab(patient: patient),
                  PatientTreatmentTab(patient: patient),
                  PatientAppointmentsTab(patient: patient),
                  PatientPaymentsTab(patient: patient),
                  PatientSimulatorTab(patient: patient),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
