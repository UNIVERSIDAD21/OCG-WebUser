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
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import 'patient_profile_screen.dart';
import 'patient_viewer_mode.dart';
import '../data/models/patient_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../providers/patients_provider.dart';
import 'tabs/patient_appointments_tab.dart';
import 'tabs/patient_clinical_history_tab.dart';
import 'tabs/patient_payments_tab.dart';
import 'tabs/patient_profile_tab.dart';
import 'tabs/patient_simulator_tab.dart';
import 'tabs/patient_treatment_tab.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  bool _deleting = false;
  bool _deletedFromThisFlow = false;

  Future<void> _deletePatient(PatientModel patient) async {
    if (_deleting) return;

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

    if (shouldDelete != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await ref.read(patientsRepositoryProvider).deletePatient(patient.id);
      if (!mounted) return;
      setState(() {
        _deletedFromThisFlow = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente eliminado correctamente')),
      );
      context.go(RouteNames.adminPatients);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));

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
          if (_deletedFromThisFlow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.go(RouteNames.adminPatients);
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de paciente')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Paciente no encontrado.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go(RouteNames.adminPatients),
                    child: const Text('Volver a pacientes'),
                  ),
                ],
              ),
            ),
          );
        }

        return _PatientDetailView(
          patient: patient,
          onDelete: _deleting ? null : () => _deletePatient(patient),
        );
      },
    );
  }
}

class _PatientDetailView extends ConsumerWidget {
  const _PatientDetailView({required this.patient, required this.onDelete});

  final PatientModel patient;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existingAppointments =
        ref.watch(appointmentsProvider).asData?.value ?? const [];
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((
        patientId: patient.id,
        patient: patient,
      )),
    );
    final selectedTreatment = _resolveHeaderTreatment(patient, treatments);
    final sectionParam = GoRouterState.of(
      context,
    ).uri.queryParameters['section'];
    final initialMobileSection = switch (sectionParam) {
      'perfil' => 0,
      'tratamiento' => 1,
      'historial' => 2,
      'citas' => 3,
      'pagos' => 4,
      'simulador' => 5,
      _ => 0,
    };

    final content = _AdminPatientWorkspace(
      patient: patient,
      initialSection: initialMobileSection,
      onEdit: () => context.go(
        RouteNames.adminPatientEdit.replaceFirst(':patientId', patient.id),
      ),
      onDelete: onDelete ?? () {},
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      final desktopContent = DefaultTabController(
        length: 6,
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
                    onPressed: onDelete,
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
                    title: 'Resumen del tratamiento principal',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OcgChip(
                          label:
                              selectedTreatment?.displayName ??
                              'Sin tratamiento principal',
                        ),
                        if (selectedTreatment != null)
                          OcgChip(
                            label: formatTreatmentStage(
                              selectedTreatment.etapaActual,
                            ),
                          ),
                        OcgChip(
                          label:
                              '${treatments.length} tratamiento${treatments.length == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SectionPanel(
                    title: 'Resumen consolidado del paciente',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OcgChip(
                          label:
                              'Saldo total: ${formatCop(_totalPending(treatments, patient))} COP',
                        ),
                        OcgChip(
                          label:
                              'Total contratado: ${formatCop(_totalAmount(treatments, patient))} COP',
                        ),
                        OcgChip(
                          label:
                              'Pagado: ${formatCop(_paidAmount(treatments, patient))} COP',
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
                  Tab(text: 'Historial clínico'),
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
                    PatientClinicalHistoryTab(
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

  PatientTreatment? _resolveHeaderTreatment(
    PatientModel patient,
    List<PatientTreatment> treatments,
  ) {
    if (treatments.isEmpty) return null;

    final preferredId = patient.id;
    for (final treatment in treatments) {
      if (treatment.isPrimary) return treatment;
    }
    for (final treatment in treatments) {
      if (treatment.id == preferredId) return treatment;
    }
    return treatments.first;
  }

  double _totalAmount(List<PatientTreatment> treatments, PatientModel patient) {
    if (treatments.isEmpty) return patient.totalTratamiento;
    return treatments.fold<double>(
      0,
      (sum, item) => sum + (item.totalTratamiento ?? 0),
    );
  }

  double _totalPending(
    List<PatientTreatment> treatments,
    PatientModel patient,
  ) {
    if (treatments.isEmpty) return patient.saldoPendiente;
    return treatments.fold<double>(
      0,
      (sum, item) => sum + (item.saldoPendiente ?? 0),
    );
  }

  double _paidAmount(List<PatientTreatment> treatments, PatientModel patient) {
    final total = _totalAmount(treatments, patient);
    final pending = _totalPending(treatments, patient);
    return (total - pending).clamp(0, double.infinity).toDouble();
  }
}

class _AdminPatientWorkspace extends ConsumerStatefulWidget {
  const _AdminPatientWorkspace({
    required this.patient,
    required this.onEdit,
    required this.onDelete,
    this.initialSection = 0,
  });

  final PatientModel patient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int initialSection;

  @override
  ConsumerState<_AdminPatientWorkspace> createState() =>
      _AdminPatientWorkspaceState();
}

class _AdminPatientWorkspaceState
    extends ConsumerState<_AdminPatientWorkspace> {
  late int _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      PatientProfileScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      _AdminTreatmentHost(patient: widget.patient),
      PatientClinicalHistoryTab(
        patientId: widget.patient.id,
        patient: widget.patient,
      ),
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
      appBarActions: [
        IconButton(
          tooltip: 'Editar paciente',
          icon: const Icon(Icons.edit_outlined),
          onPressed: widget.onEdit,
        ),
        IconButton(
          tooltip: 'Eliminar paciente',
          icon: const Icon(Icons.delete_outline, color: OcgColors.error),
          onPressed: widget.onDelete,
        ),
      ],
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
                _sectionChip('Historial', 2),
                _sectionChip('Citas', 3),
                _sectionChip('Pagos', 4),
                _sectionChip('Simulador', 5),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(index: _section, children: views),
          ),
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
        Expanded(
          child: PatientTreatmentTab(patientId: patient.id, patient: patient),
        ),
      ],
    );
  }
}
