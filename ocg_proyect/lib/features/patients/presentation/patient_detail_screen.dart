import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/components/detail_header.dart';
import '../../admin/presentation/web/components/action_toolbar.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../dashboard/presentation/admin_appointments_screen.dart';
import '../../dashboard/presentation/patient_appointments_screen.dart';
import '../../payments/presentation/patient_payments_screen.dart';
import '../../simulator/presentation/patient_simulations_screen.dart';
import 'patient_profile_screen.dart';
import 'patient_viewer_mode.dart';
import '../data/models/patient_model.dart';
import '../../appointments/providers/appointments_provider.dart';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
        content: Text(
          '¿Seguro que deseas eliminar a ${patient.nombre}? Esta acción no se puede deshacer.',
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existingAppointments = ref.watch(appointmentsProvider).asData?.value ?? const [];

    final content = _AdminPatientWorkspace(patient: patient);

    if (WebLayoutContext.useDesktopShell(context)) {
      final desktopContent = DefaultTabController(
        length: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailHeader(
              title: patient.nombre,
              subtitle: 'Expediente clínico y financiero del paciente',
              trailing: ActionToolbar(
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.adminPatients),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go(
                      RouteNames.adminPatientEdit.replaceFirst(
                        ':patientId',
                        patient.id,
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _deletePatient(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SectionPanel(
                    title: 'Resumen clínico',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OcgChip(
                          label: patient.tipoTratamiento?.name ?? 'Pendiente',
                        ),
                        OcgChip(
                          label: formatTreatmentStage(patient.etapaActual),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SectionPanel(
                    title: 'Resumen financiero',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OcgChip(
                          label:
                              'Saldo: ${formatCop(patient.saldoPendiente)} COP',
                        ),
                        OcgChip(
                          label:
                              'Total: ${formatCop(patient.totalTratamiento)} COP',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
              ),
              child: const TabBar(
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
            const SizedBox(height: 8),
            SectionPanel(
              title: 'Detalle',
              trailing: FilledButton.icon(
                onPressed: () => AdminAppointmentsScreen.showCreateDialog(
                  context,
                  ref,
                  preselectedPatient: patient,
                  existingAppointments: existingAppointments,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Agendar cita'),
              ),
              child: SizedBox(
                height: 760,
                child: TabBarView(
                  children: [
                    PatientProfileTab(patient: patient),
                    PatientTreatmentTab(
                      patientId: patient.id,
                      patient: patient,
                    ),
                    PatientAppointmentsTab(patient: patient),
                    PatientPaymentsTab(patientId: patient.id),
                    PatientSimulatorTab(patient: patient),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      return AdminWebShell(
        title: 'Detalle de paciente',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: desktopContent,
        ),
      );
    }

    return content;
  }
}

class _AdminPatientWorkspace extends ConsumerStatefulWidget {
  const _AdminPatientWorkspace({required this.patient});

  final PatientModel patient;

  @override
  ConsumerState<_AdminPatientWorkspace> createState() =>
      _AdminPatientWorkspaceState();
}

class _AdminPatientWorkspaceState extends ConsumerState<_AdminPatientWorkspace> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final views = [
      PatientProfileScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      _AdminTreatmentHost(patient: widget.patient),
      PatientAppointmentsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      PatientPaymentsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      PatientSimulationsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
    ];

    return OcgAdaptiveScaffold(
      selectedIndex: 1,
      title: 'Paciente: ${widget.patient.nombre}',
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _sectionChip('Perfil', 0),
                _sectionChip('Tratamiento', 1),
                _sectionChip('Citas', 2),
                _sectionChip('Pagos', 3),
                _sectionChip('Simulador', 4),
              ],
            ),
          ),
          Expanded(child: IndexedStack(index: _section, children: views)),
        ],
      ),
    );
  }

  Widget _sectionChip(String text, int index) {
    final active = _section == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        label: Text(text),
        onSelected: (_) => setState(() => _section = index),
      ),
    );
  }
}

class _AdminTreatmentHost extends StatelessWidget {
  const _AdminTreatmentHost({required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 16,
            20,
            14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [OcgColors.espresso, Color(0xFF4A3628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tratamiento del paciente',
                style: TextStyle(
                  color: OcgColors.ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Seguimiento clínico y etapas desde administración',
                style: TextStyle(color: Color(0xCCF8F5F0), fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(child: PatientTreatmentTab(patientId: patient.id, patient: patient)),
      ],
    );
  }
}
