import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../../shared/utils/ui_formatters.dart';
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

class _PatientDetailView extends ConsumerWidget {
  const _PatientDetailView({required this.patient});

  final PatientModel patient;

  Future<void> _deletePatient(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: Text('¿Seguro que deseas eliminar a ${patient.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(patientsRepositoryProvider).deletePatient(patient.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente eliminado correctamente')),
      );
      context.go(RouteNames.adminPatients);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: OcgAdaptiveScaffold(
        selectedIndex: 1,
        body: Column(
          children: [
            Material(
              color: OcgColors.espresso,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Volver',
                            onPressed: () => context.go(RouteNames.adminPatients),
                            icon: const Icon(Icons.arrow_back, color: OcgColors.ivory),
                          ),
                          Expanded(
                            child: Text(
                              patient.nombre,
                              style: const TextStyle(
                                color: OcgColors.ivory,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar paciente',
                            onPressed: () => _deletePatient(context, ref),
                            icon: const Icon(Icons.delete_outline, color: OcgColors.ivory),
                          ),
                          IconButton(
                            tooltip: 'Editar paciente',
                            onPressed: () => context.go(
                              RouteNames.adminPatientEdit.replaceFirst(':patientId', patient.id),
                            ),
                            icon: const Icon(Icons.edit, color: OcgColors.ivory),
                          ),
                        ],
                      ),
                    ),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: OcgColors.ivory,
                      unselectedLabelColor: OcgColors.sand,
                      indicatorColor: OcgColors.bronze,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Perfil'),
                        Tab(text: 'Tratamiento'),
                        Tab(text: 'Citas'),
                        Tab(text: 'Pagos'),
                        Tab(text: 'Simulador'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              color: OcgColors.mist,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OcgChip(label: patient.tipoTratamiento?.name ?? 'Pendiente'),
                  OcgChip(label: formatTreatmentStage(patient.etapaActual)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PatientProfileTab(patient: patient),
                  PatientTreatmentTab(patientId: patient.id, patient: patient),
                  PatientAppointmentsTab(patient: patient),
                  PatientPaymentsTab(patientId: patient.id),
                  PatientSimulatorTab(patient: patient),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(
        currentRoute: RouteNames.adminPatients,
        title: 'Detalle de paciente',
        child: content,
      );
    }

    return content;
  }
}
