import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../dashboard/presentation/admin_appointments_screen.dart';
import '../../dashboard/presentation/patient_appointments_screen.dart';
import '../../payments/presentation/patient_payments_screen.dart';
import '../../payments/providers/payments_provider.dart';
import '../../simulator/data/models/simulation_model.dart';
import '../../simulator/presentation/patient_simulations_screen.dart';
import '../../simulator/providers/simulation_provider.dart';
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
      final layout = AdminDesktopLayoutScope.maybeOf(context);
      final tier = layout?.tier ?? AdminDesktopTier.standard;
      final sectionGap = layout?.sectionSpacing ?? 16;
      final panelGap = layout?.panelGap ?? 12;
      final headerPadding = switch (tier) {
        AdminDesktopTier.wide => const EdgeInsets.fromLTRB(24, 20, 24, 14),
        AdminDesktopTier.standard => const EdgeInsets.fromLTRB(22, 18, 22, 14),
        AdminDesktopTier.compact => const EdgeInsets.fromLTRB(18, 16, 18, 12),
        AdminDesktopTier.tight => const EdgeInsets.fromLTRB(16, 14, 16, 12),
      };
      final titleSize = switch (tier) {
        AdminDesktopTier.wide => 30.0,
        AdminDesktopTier.standard => 28.0,
        AdminDesktopTier.compact => 26.0,
        AdminDesktopTier.tight => 24.0,
      };

      final desktopContent = DefaultTabController(
        length: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: headerPadding,
                    decoration: BoxDecoration(
                      color: OcgColors.ivory,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: OcgColors.bronze.withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: panelGap,
                          runSpacing: panelGap,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.go(RouteNames.adminPatients),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Volver'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: OcgColors.espresso,
                                side: BorderSide(
                                  color: OcgColors.bronze.withOpacity(0.22),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: tier == AdminDesktopTier.tight
                                    ? 220
                                    : 280,
                                maxWidth: tier == AdminDesktopTier.wide
                                    ? 540
                                    : 480,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.nombre,
                                    style: TextStyle(
                                      color: OcgColors.espresso,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vista clínica, financiera y operativa del paciente',
                                    style: TextStyle(
                                      color: OcgColors.bronze,
                                      fontSize: tier == AdminDesktopTier.tight
                                          ? 12
                                          : 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => context.go(
                                    RouteNames.adminPatientEdit.replaceFirst(
                                      ':patientId',
                                      patient.id,
                                    ),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Editar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onDelete,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: OcgColors.error,
                                  ),
                                  label: const Text('Eliminar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: OcgColors.error,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      AdminAppointmentsScreen.showCreateDialog(
                                        context,
                                        ref,
                                        preselectedPatient: patient,
                                        existingAppointments:
                                            existingAppointments,
                                      ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agendar cita'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: sectionGap),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tier == AdminDesktopTier.tight ? 10 : 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8DDD2)),
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
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  Expanded(
                    child: SectionPanel(
                      title: 'Detalle del paciente',
                      expandChild: true,
                      child: TabBarView(
                        children: [
                          _PatientProfileAdminTab(
                            patient: patient,
                            onEdit: () => context.go(
                              RouteNames.adminPatientEdit.replaceFirst(
                                ':patientId',
                                patient.id,
                              ),
                            ),
                            onDelete: onDelete,
                          ),
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
          },
        ),
      );

      return AdminWebShell(
        title: 'Detalle de paciente',
        scrollable: false,
        child: desktopContent,
      );
    }

    return content;
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
  late final Set<int> _loadedSections;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 5);
    _loadedSections = {_section};
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsProvider).asData?.value ?? const <AppointmentModel>[];
    final patientAppointments = appointments
        .where((item) => item.patientId == widget.patient.id)
        .toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    final nextAppointment = patientAppointments.cast<AppointmentModel?>().firstWhere(
      (item) => item != null && item.fechaHora.isAfter(DateTime.now()),
      orElse: () => null,
    );
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((
        patientId: widget.patient.id,
        patient: widget.patient,
      )),
    );
    final activeTreatment = treatments.cast<dynamic?>().firstWhere(
      (item) => item?.isFinished != true,
      orElse: () => treatments.isNotEmpty ? treatments.first : null,
    );
    final paymentsResolution = ref.watch(
      effectivePatientPaymentsProvider((
        patientId: widget.patient.id,
        patient: widget.patient,
      )),
    );
    final simulations =
        ref.watch(patientSimulationsProvider(widget.patient.id)).asData?.value ??
        const <SimulationModel>[];
    final latestSimulation = simulations.isEmpty ? null : simulations.first;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(nextAppointment, latestSimulation),
            const SizedBox(height: 16),
            _buildQuickActionsCard(context),
            const SizedBox(height: 16),
            _buildTreatmentCard(activeTreatment),
            const SizedBox(height: 16),
            _buildPaymentsCard(paymentsResolution),
            const SizedBox(height: 16),
            _buildAppointmentsCard(nextAppointment),
            const SizedBox(height: 16),
            _buildSimulatorCard(latestSimulation),
            const SizedBox(height: 16),
            _buildPhotosCard(),
            const SizedBox(height: 20),
            _buildSectionShortcutRow(),
            const SizedBox(height: 14),
            SizedBox(
              height: 720,
              child: IndexedStack(
                index: _section,
                children: List.generate(6, (index) {
                  if (!_loadedSections.contains(index)) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('patient-detail-section-$index'),
                      child: _buildSection(index),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(int index) {
    return switch (index) {
      0 => PatientProfileScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      1 => _AdminTreatmentHost(patient: widget.patient),
      2 => PatientClinicalHistoryTab(
        patientId: widget.patient.id,
        patient: widget.patient,
      ),
      3 => PatientAppointmentsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      4 => PatientPaymentsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      5 => PatientSimulationsScreen(
        embedded: true,
        patientIdOverride: widget.patient.id,
        viewerMode: PatientViewerMode.adminViewer,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _sectionChip(String text, int index) {
    final active = _section == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        label: Text(text),
        onSelected: (_) => setState(() {
          _section = index;
          _loadedSections.add(index);
        }),
      ),
    );
  }

  Widget _buildSectionShortcutRow() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _sectionChip('Resumen', 0),
          _sectionChip('Tratamiento', 1),
          _sectionChip('Citas', 3),
          _sectionChip('Pagos', 4),
          _sectionChip('Simulador', 5),
          _sectionChip('Historial', 2),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    AppointmentModel? nextAppointment,
    SimulationModel? latestSimulation,
  ) {
    return _patientCard(
      title: 'Resumen',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.patient.nombre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.patient.telefono.trim().isNotEmpty)
            Text(
              'Contacto: ${widget.patient.telefono}',
              style: const TextStyle(color: OcgColors.ink),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoPill('Tratamiento', widget.patient.treatmentStatusLabel),
              _infoPill('Saldo', _money(widget.patient.saldoPendiente)),
              _infoPill(
                'Próxima cita',
                nextAppointment == null
                    ? 'Sin agendar'
                    : _dateTime(nextAppointment.fechaHora),
              ),
              _infoPill(
                'Última simulación',
                latestSimulation == null
                    ? 'Sin simulaciones'
                    : _simulationStatusLabel(latestSimulation.status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return _patientCard(
      title: 'Acciones rápidas',
      icon: Icons.flash_on_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _quickActionButton(
            icon: Icons.calendar_month_outlined,
            label: 'Agendar cita',
            onTap: () => AdminAppointmentsScreen.showCreateDialog(
              context,
              ref,
              preselectedPatient: widget.patient,
              existingAppointments: ref.watch(appointmentsProvider).asData?.value ?? const [],
            ),
          ),
          _quickActionButton(
            icon: Icons.payments_outlined,
            label: 'Registrar pago',
            onTap: () => _openSection(4),
          ),
          _quickActionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Tomar foto',
            onTap: () => _openSection(5),
          ),
          _quickActionButton(
            icon: Icons.auto_awesome_outlined,
            label: 'Abrir simulador',
            onTap: () => _openSection(5),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(dynamic activeTreatment) {
    final treatmentName = activeTreatment?.displayName ??
        widget.patient.tipoTratamiento?.name ??
        'Sin tratamiento activo';
    final stageName = activeTreatment?.stageLabel ?? stageNames[widget.patient.etapaActual] ?? 'Sin etapa';
    final total = activeTreatment?.totalTratamiento ?? widget.patient.totalTratamiento;
    final pending = activeTreatment?.saldoPendiente ?? widget.patient.saldoPendiente;
    final lastNote = activeTreatment?.notas?.toString().trim().isNotEmpty == true
        ? activeTreatment.notas.toString().trim()
        : widget.patient.notasClinicas.trim().isNotEmpty
            ? widget.patient.notasClinicas.trim()
            : 'Sin notas clínicas registradas.';

    return _patientCard(
      title: 'Tratamiento',
      icon: Icons.monitor_heart_outlined,
      actionText: 'Ver tratamiento',
      onAction: () => _openSection(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(treatmentName, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
          const SizedBox(height: 8),
          Text('Etapa actual: $stageName', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 6),
          Text('Valor total: ${_money(total)}', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 6),
          Text('Saldo pendiente: ${_money(pending)}', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 10),
          Text(
            lastNote,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: OcgColors.bronze),
          ),
          const SizedBox(height: 10),
          const Text(
            'Para edición completa del tratamiento, usa la versión de escritorio.',
            style: TextStyle(color: OcgColors.bronze, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsCard(dynamic paymentsResolution) {
    final total = paymentsResolution.paymentAccounts.fold<double>(
      0,
      (sum, item) => sum + item.payment.totalTratamiento,
    );
    final paid = paymentsResolution.paymentAccounts.fold<double>(
      0,
      (sum, item) => sum + item.payment.montoPagado,
    );
    final pending = paymentsResolution.paymentAccounts.fold<double>(
      0,
      (sum, item) => sum + item.payment.saldoPendiente,
    );
    final latestTx = paymentsResolution.transactions.isEmpty
        ? null
        : paymentsResolution.transactions.first;

    return _patientCard(
      title: 'Pagos',
      icon: Icons.payments_outlined,
      actionText: 'Ver pagos',
      onAction: () => _openSection(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total tratamiento: ${_money(total)}', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 6),
          Text('Total pagado: ${_money(paid)}', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 6),
          Text('Saldo pendiente: ${_money(pending)}', style: const TextStyle(color: OcgColors.ink)),
          const SizedBox(height: 10),
          Text(
            latestTx == null
                ? 'Último pago: sin registros.'
                : 'Último pago: ${_money(latestTx.monto)} · ${_date(latestTx.fecha)}',
            style: const TextStyle(color: OcgColors.bronze),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsCard(AppointmentModel? nextAppointment) {
    return _patientCard(
      title: 'Citas',
      icon: Icons.calendar_month_outlined,
      actionText: 'Ver agenda',
      onAction: () => _openSection(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nextAppointment == null
                ? 'Sin próxima cita agendada.'
                : 'Próxima cita: ${_dateTime(nextAppointment.fechaHora)}',
            style: const TextStyle(color: OcgColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            nextAppointment == null
                ? 'Estado: pendiente de programación'
                : 'Estado: ${nextAppointment.estado.name}',
            style: const TextStyle(color: OcgColors.bronze),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => AdminAppointmentsScreen.showCreateDialog(
              context,
              ref,
              preselectedPatient: widget.patient,
              existingAppointments: ref.watch(appointmentsProvider).asData?.value ?? const [],
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agendar cita'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorCard(SimulationModel? latestSimulation) {
    return _patientCard(
      title: 'Simulador',
      icon: Icons.auto_awesome_outlined,
      actionText: 'Abrir simulador',
      onAction: () => _openSection(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latestSimulation == null
                ? 'Crea una simulación de sonrisa a partir de una foto del paciente.'
                : 'Última simulación: ${_simulationStatusLabel(latestSimulation.status)}',
            style: const TextStyle(color: OcgColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            latestSimulation?.hasResult == true
                ? 'Hay una simulación lista para revisión.'
                : 'Toma una foto frontal del paciente para iniciar la simulación.',
            style: const TextStyle(color: OcgColors.bronze),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openSection(5),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
              FilledButton.icon(
                onPressed: () => _openSection(5),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Abrir simulador'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
    return _patientCard(
      title: 'Fotos',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acceso rápido a fotos clínicas del paciente.',
            style: TextStyle(color: OcgColors.ink),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openSection(0),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Ver fotos'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSection(5),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSection(5),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Subir foto'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patientCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: OcgColors.espresso),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: OcgColors.espresso,
                    ),
                  ),
                ),
                if (actionText != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionText)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 148,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          backgroundColor: OcgColors.espresso,
          foregroundColor: OcgColors.ivory,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: OcgColors.bronze, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: OcgColors.espresso, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _openSection(int index) {
    setState(() {
      _section = index;
      _loadedSections.add(index);
    });
  }

  String _money(num value) => '\$${value.toStringAsFixed(0)}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _simulationStatusLabel(SimulationStatus status) {
    return switch (status) {
      SimulationStatus.draft => 'Borrador',
      SimulationStatus.generating => 'Generando',
      SimulationStatus.ready => 'Lista',
      SimulationStatus.shared => 'Compartida',
      SimulationStatus.failed => 'Con error',
      SimulationStatus.archived => 'Archivada',
    };
  }
}

class _PatientProfileAdminTab extends StatelessWidget {
  const _PatientProfileAdminTab({
    required this.patient,
    required this.onEdit,
    required this.onDelete,
  });

  final PatientModel patient;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PatientProfileTab(patient: patient);
  }
}

class PatientDetailDesktopWorkspaceTestHarness extends StatelessWidget {
  const PatientDetailDesktopWorkspaceTestHarness({
    super.key,
    required this.patient,
  });

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Builder(
        builder: (context) {
          final layout = AdminDesktopLayoutScope.maybeOf(context);
          final tier = layout?.tier ?? AdminDesktopTier.standard;
          final sectionGap = layout?.sectionSpacing ?? 16;
          final panelGap = layout?.panelGap ?? 12;
          final titleSize = switch (tier) {
            AdminDesktopTier.wide => 30.0,
            AdminDesktopTier.standard => 28.0,
            AdminDesktopTier.compact => 26.0,
            AdminDesktopTier.tight => 24.0,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_shared_outlined),
                        SizedBox(width: panelGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.nombre,
                                style: TextStyle(
                                  color: OcgColors.espresso,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Vista clínica, financiera y operativa del paciente',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agendar cita'),
                        ),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                    const TabBar(
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
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              const Expanded(
                child: TabBarView(
                  children: [
                    Center(child: Text('Perfil content')),
                    Center(child: Text('Tratamiento content')),
                    Center(child: Text('Historial content')),
                    Center(child: Text('Citas content')),
                    Center(child: Text('Pagos content')),
                    Center(child: Text('Simulador content')),
                  ],
                ),
              ),
            ],
          );
        },
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
