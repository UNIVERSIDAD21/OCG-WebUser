import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/widgets/ocg_confirm_dialog.dart';
import '../../../shared/widgets/ocg_segmented_tabs.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../auth/providers/auth_providers.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../dashboard/presentation/admin_appointments_screen.dart';
import '../../payments/data/models/payment_model.dart';
import '../../payments/presentation/widgets/register_payment_dialog.dart';
import '../../payments/providers/payments_provider.dart';
import '../../simulator/data/models/simulation_model.dart';
import '../../simulator/providers/simulation_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/presentation/widgets/manage_patient_treatment_dialog.dart';
import '../../treatment/presentation/widgets/update_stage_dialog.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import '../data/models/patient_data_resolution.dart';
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
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    this.embeddedInAdminMobileShell = false,
  });

  final String patientId;
  final bool embeddedInAdminMobileShell;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  bool _deleting = false;
  bool _deletedFromThisFlow = false;

  Future<void> _deletePatient(PatientModel patient) async {
    if (_deleting) return;

    final shouldDelete = await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.danger,
      title: 'Eliminar paciente',
      message: '¿Seguro que deseas eliminar a ${patient.nombre}? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      onConfirm: () {},
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
          embeddedInAdminMobileShell: widget.embeddedInAdminMobileShell,
          onDelete: _deleting ? null : () => _deletePatient(patient),
        );
      },
    );
  }
}



class _PatientDetailView extends ConsumerWidget {
  const _PatientDetailView({
    required this.patient,
    required this.embeddedInAdminMobileShell,
    required this.onDelete,
  });

  final PatientModel patient;
  final bool embeddedInAdminMobileShell;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existingAppointments =
        ref.watch(appointmentsProvider).asData?.value ?? const [];
    final sectionParam = GoRouterState.of(
      context,
    ).uri.queryParameters['section'];
    final initialMobileSection = switch (sectionParam) {
      'perfil' || 'resumen' => 0,
      'tratamiento' || 'tratamientos' => 1,
      'pagos' => 2,
      'docs' || 'documentos' || 'historial' => 3,
      'citas' => 4,
      'simulador' => 5,
      _ => 0,
    };


    final content = _AdminPatientWorkspace(
      patient: patient,
      embeddedInAdminMobileShell: embeddedInAdminMobileShell,
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

      final initialDesktopTab = switch (sectionParam) {
        'tratamiento' ||
        'tratamientos' => 1,
        'pagos' => 2,
        'docs' ||
        'documentos' ||
        'historial' => 3,
        'citas' => 4,
        'simulador' => 5,
        _ => 0,
      };

      final desktopContent = DefaultTabController(
        length: 6,
        initialIndex: initialDesktopTab,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Tab(text: 'Pagos'),
                  Tab(text: 'Documentos clínicos'),
                  Tab(text: 'Citas'),
                  Tab(text: 'Simulador'),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            // Header card (nombre + acciones)
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
                        onPressed: () =>
                            context.go(RouteNames.adminPatients),
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
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                            ),
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
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            // ── Tab content: SectionPanel con TabBarView de altura
            // explícita. Se usa LayoutBuilder para detectar si el padre
            // da altura finita; si no, fallback a 700px.
            LayoutBuilder(
              builder: (context, outer) {
                final tabHeight = outer.maxHeight.isFinite
                    ? (outer.maxHeight * 0.78).clamp(300.0, 2000.0)
                    : 700.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Detalle del paciente',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: OcgColors.ivory,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: OcgColors.bronze.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: OcgColors.ink.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: tabHeight,
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
                              scrollable: false,
                            ),
                            PatientPaymentsTab(
                              patientId: patient.id,
                              scrollable: false,
                            ),
                            PatientClinicalHistoryTab(
                              patientId: patient.id,
                              patient: patient,
                              scrollable: false,
                            ),
                            PatientAppointmentsTab(patient: patient),
                            PatientSimulatorTab(patient: patient),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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
    required this.embeddedInAdminMobileShell,
    required this.onEdit,
    required this.onDelete,
    this.initialSection = 0,
  });

  final PatientModel patient;
  final bool embeddedInAdminMobileShell;
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
    final appointments =
        ref.watch(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    final patientAppointments =
        appointments
            .where((item) => item.patientId == widget.patient.id)
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    final nextAppointment = patientAppointments
        .cast<AppointmentModel?>()
        .firstWhere(
          (item) => item != null && item.fechaHora.isAfter(DateTime.now()),
          orElse: () => null,
        );
    final treatments = ref.watch(
      effectivePatientTreatmentsProvider((
        patientId: widget.patient.id,
        patient: widget.patient,
      )),
    );
    final paymentsResolution = ref.watch(
      effectivePatientPaymentsProvider((
        patientId: widget.patient.id,
        patient: widget.patient,
      )),
    );
    final simulations =
        ref
            .watch(patientSimulationsProvider(widget.patient.id))
            .asData
            ?.value ??
        const <SimulationModel>[];
    final latestSimulation = simulations.isEmpty ? null : simulations.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        leading: widget.embeddedInAdminMobileShell
            ? IconButton(
                tooltip: 'Volver a pacientes',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(RouteNames.adminPatients),
              )
            : null,
        title: Text('Paciente: ${widget.patient.nombre}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientHeaderCard(nextAppointment, paymentsResolution),
            const SizedBox(height: 16),
            _buildQuickActionsCard(context),
            const SizedBox(height: 16),
            _buildSectionShortcutRow(
              treatmentsCount: treatments.length,
              appointmentsCount: patientAppointments.length,
              simulationsCount: simulations.length,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_section),
                child: _buildVisibleMobileSection(
                  treatments: treatments,
                  nextAppointment: nextAppointment,
                  latestSimulation: latestSimulation,
                  paymentsResolution: paymentsResolution,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(int index) {
    return switch (index) {
      2 => PatientPaymentsTab(
        patientId: widget.patient.id,
        scrollable: false,
      ),
      3 => PatientClinicalHistoryTab(
        patientId: widget.patient.id,
        patient: widget.patient,
        scrollable: false,
      ),
      4 => PatientAppointmentsTab(patient: widget.patient, scrollable: false),
      5 => PatientSimulatorTab(patient: widget.patient, scrollable: false),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSectionShortcutRow({
    required int treatmentsCount,
    required int appointmentsCount,
    required int simulationsCount,
  }) {
    return OcgSegmentedTabs<int>(
      selectedValue: _section,
      onChanged: _openSection,
      items: [
        const OcgSegmentedTabItem(
          value: 0,
          label: 'Perfil',
          icon: Icons.person_outline,
        ),
        OcgSegmentedTabItem(
          value: 1,
          label: 'Tratamientos',
          icon: Icons.monitor_heart_outlined,
          badge: treatmentsCount == 0 ? null : '$treatmentsCount',
        ),
        const OcgSegmentedTabItem(
          value: 2,
          label: 'Pagos',
          icon: Icons.payments_outlined,
        ),
        const OcgSegmentedTabItem(
          value: 3,
          label: 'Documentos clínicos',
          icon: Icons.description_outlined,
        ),
        OcgSegmentedTabItem(
          value: 4,
          label: 'Citas',
          icon: Icons.calendar_month_outlined,
          badge: appointmentsCount == 0 ? null : '$appointmentsCount',
        ),
        OcgSegmentedTabItem(
          value: 5,
          label: 'Simulador',
          icon: Icons.auto_awesome_outlined,
          badge: simulationsCount == 0 ? null : '$simulationsCount',
        ),
      ],
    );
  }

  Widget _buildPatientHeaderCard(
    AppointmentModel? nextAppointment,
    EffectivePatientDataResolution paymentsResolution,
  ) {
    final contact = widget.patient.telefono.trim().isEmpty
        ? 'Sin contacto registrado'
        : widget.patient.telefono.trim();
    final pending = paymentsResolution.paymentAccounts.isEmpty
        ? widget.patient.saldoPendiente
        : paymentsResolution.paymentAccounts.fold<double>(
            0.0,
            (sum, item) => sum + item.payment.saldoPendiente,
          );

    return _patientCard(
      title: 'Paciente',
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
          Text(
            'Contacto: $contact',
            style: const TextStyle(color: OcgColors.ink),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoPill('Estado', widget.patient.treatmentStatusLabel),
              _infoPill('Saldo pendiente', _money(pending)),
              _infoPill(
                'Próxima cita',
                nextAppointment == null
                    ? 'Sin agendar'
                    : _dateTime(nextAppointment.fechaHora),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcgColors.espresso,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  side: BorderSide(color: OcgColors.bronze.withOpacity(0.28)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcgColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  side: BorderSide(color: OcgColors.error.withOpacity(0.42)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibleMobileSection({
    required List<PatientTreatment> treatments,
    required AppointmentModel? nextAppointment,
    required SimulationModel? latestSimulation,
    required EffectivePatientDataResolution paymentsResolution,
  }) {
    return switch (_section) {
      0 => PatientProfileTab(patient: widget.patient, scrollable: false),
      1 => PatientTreatmentTab(
        patientId: widget.patient.id,
        patient: widget.patient,
        scrollable: false,
      ),
      2 => Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
        ),
        child: _buildSection(2),
      ),
      3 => Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
        ),
        child: _buildSection(3),
      ),
      4 => Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
        ),
        child: _buildSection(4),
      ),
      5 => Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
        ),
        child: _buildSection(5),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _openManageTreatmentDialog([PatientTreatment? treatment]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ManagePatientTreatmentDialog(
        patientId: widget.patient.id,
        patientName: widget.patient.nombre,
        initialTreatment: treatment,
      ),
    );
  }

  Future<void> _openUpdateStageDialog(PatientTreatment treatment) async {
    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? '';
    await showDialog<void>(
      context: context,
      builder: (_) => UpdateStageDialog(
        patientId: widget.patient.id,
        treatmentId: treatment.id.startsWith('legacy-primary-')
            ? null
            : treatment.id,
        etapaActual: treatment.etapaActual,
        adminId: adminId,
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

  Widget _buildQuickActionsCard(BuildContext context) {
    return _patientCard(
      title: 'Acciones rápidas',
      icon: Icons.flash_on_outlined,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          _quickActionButton(
            icon: Icons.calendar_month_outlined,
            label: 'Agendar cita',
            onTap: () => AdminAppointmentsScreen.showCreateDialog(
              context,
              ref,
              preselectedPatient: widget.patient,
              existingAppointments:
                  ref.watch(appointmentsProvider).asData?.value ?? const [],
            ),
          ),
          _quickActionButton(
            icon: Icons.payments_outlined,
            label: 'Registrar pago',
            onTap: () => _openSection(2),
          ),
          _quickActionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Tomar foto',
            onTap: () => _startSimulatorCameraFlow(),
          ),
          _quickActionButton(
            icon: Icons.auto_awesome_outlined,
            label: 'Abrir simulador',
            onTap: () => _openSection(3),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          Text(
            label,
            style: const TextStyle(color: OcgColors.bronze, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentAccountCard({
    required EffectivePatientPaymentAccount account,
    required PatientTreatment? treatment,
    required List<PaymentTransaction> allTransactions,
  }) {
    final treatmentName =
        treatment?.displayName ??
        (account.treatmentId == null
            ? 'Cuenta legacy / migrada'
            : 'Tratamiento sin identificar');
    final roleLabel = account.treatmentId == null
        ? 'Legacy'
        : (treatment?.isPrimary == true ? 'Principal' : 'Secundario');
    final stateLabel = treatment?.statusLabel ?? 'Cuenta migrada';
    final relatedTransactions = allTransactions.where((tx) {
      if (account.treatmentId == null) return tx.treatmentId == null;
      return tx.treatmentId == account.treatmentId;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            treatmentName,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusBadge(roleLabel),
              _statusBadge(stateLabel),
              if (account.treatmentId == null) _statusBadge('Migrado'),
            ],
          ),
          const SizedBox(height: 12),
          _mobileMetricRow('Total', _money(account.payment.totalTratamiento)),
          _mobileMetricRow('Pagado', _money(account.payment.montoPagado)),
          _mobileMetricRow('Pendiente', _money(account.payment.saldoPendiente)),
          _mobileMetricRow(
            'Próximo pago',
            account.payment.fechaProximoPago == null
                ? 'Sin fecha registrada'
                : _date(account.payment.fechaProximoPago!),
          ),
          const SizedBox(height: 10),
          if (relatedTransactions.isEmpty)
            const Text(
              'Este tratamiento aún no tiene pagos registrados.',
              style: TextStyle(color: OcgColors.bronze),
            )
          else
            Text(
              '${relatedTransactions.length} pago${relatedTransactions.length == 1 ? '' : 's'} registrado${relatedTransactions.length == 1 ? '' : 's'} en esta cuenta.',
              style: const TextStyle(color: OcgColors.bronze),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: account.treatmentId == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => RegisterPaymentDialog(
                          patientId: widget.patient.id,
                          treatmentId: account.treatmentId!,
                          saldoPendiente: account.payment.saldoPendiente,
                        ),
                      ),
                icon: const Icon(Icons.add_card_outlined, size: 18),
                label: const Text('Registrar pago'),
              ),
              OutlinedButton.icon(
                onPressed: relatedTransactions.isEmpty
                    ? null
                    : () => _showAccountTransactionHistory(
                        treatmentName,
                        relatedTransactions,
                        treatment,
                      ),
                icon: const Icon(Icons.history_outlined, size: 18),
                label: Text(
                  relatedTransactions.isEmpty
                      ? 'Sin historial'
                      : 'Historial de este tratamiento',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCard(
    PaymentTransaction tx,
    PatientTreatment? treatment,
  ) {
    final treatmentLabel =
        treatment?.displayName ??
        (tx.treatmentId == null
            ? 'Tratamiento no identificado / cuenta legacy'
            : 'Tratamiento asociado no encontrado');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _date(tx.fecha),
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _mobileMetricRow('Valor', _money(tx.monto)),
          _mobileMetricRow('Método', _paymentMethodLabel(tx.metodo)),
          _mobileMetricRow('Estado', _paymentStateLabel(tx)),
          _mobileMetricRow('Tratamiento', treatmentLabel),
          if ((tx.referencia ?? '').trim().isNotEmpty)
            _mobileMetricRow('Referencia', tx.referencia!.trim()),
          if ((tx.notas ?? '').trim().isNotEmpty)
            _mobileMetricRow('Nota', tx.notas!.trim()),
        ],
      ),
    );
  }

  PatientTreatment? _resolveTreatmentForAccount(
    List<PatientTreatment> treatments,
    EffectivePatientPaymentAccount account,
  ) {
    if (account.treatmentId == null) return null;
    for (final treatment in treatments) {
      if (treatment.id == account.treatmentId) return treatment;
    }
    return null;
  }

  PatientTreatment? _resolveTreatmentForTransaction(
    List<PatientTreatment> treatments,
    List<EffectivePatientPaymentAccount> accounts,
    PaymentTransaction tx,
  ) {
    if (tx.treatmentId != null) {
      for (final treatment in treatments) {
        if (treatment.id == tx.treatmentId) return treatment;
      }
    }

    for (final account in accounts) {
      if (account.treatmentId == tx.treatmentId &&
          account.treatmentId != null) {
        return _resolveTreatmentForAccount(treatments, account);
      }
    }
    return null;
  }

  Widget _mobileMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: OcgColors.bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: OcgColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.efectivo => 'Efectivo',
      PaymentMethod.transferencia => 'Transferencia',
      PaymentMethod.payu => 'PayU',
    };
  }

  String _paymentStateLabel(PaymentTransaction tx) {
    if (tx.payuTransactionId?.trim().isNotEmpty == true) return 'Confirmado';
    if (tx.payuOrderId?.trim().isNotEmpty == true) return 'Procesado';
    return 'Registrado';
  }

  Widget _statusBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2EC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: OcgColors.espresso,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showTreatmentNotes(PatientTreatment treatment) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatment.displayName,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  treatment.notas?.trim().isNotEmpty == true
                      ? treatment.notas!.trim()
                      : 'Sin notas registradas para este tratamiento.',
                  style: const TextStyle(color: OcgColors.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAccountTransactionHistory(
    String title,
    List<PaymentTransaction> transactions,
    PatientTreatment? treatment,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  treatment?.statusLabel ?? 'Cuenta legacy / migrada',
                  style: const TextStyle(color: OcgColors.bronze),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 360,
                  child: ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildMobileTransactionCard(
                          transactions[index],
                          treatment,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startSimulatorCameraFlow() async {
    final adminId = ref.read(authStateProvider).asData?.value?.uid ?? '';
    if (adminId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo validar la sesión para abrir la cámara.'),
        ),
      );
      return;
    }

    _openSection(3);
    ref.read(simulatorFlowProvider.notifier).resetFlow();

    try {
      await ref
          .read(simulatorFlowProvider.notifier)
          .pickOriginalFromCamera(
            patientId: widget.patient.id,
            adminId: adminId,
            treatmentType: widget.patient.tipoTratamiento,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la cámara en este momento.'),
        ),
      );
    }
  }

  void _openSection(int index) {
    setState(() {
      _section = index.clamp(0, 5);
    });
  }

  String _money(num value) => '\$${formatCop(value)}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
                        Tab(text: 'Pagos'),
                        Tab(text: 'Documentos clínicos'),
                        Tab(text: 'Citas'),
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
                    Center(child: Text('Pagos content')),
                    Center(child: Text('Documentos clínicos content')),
                    Center(child: Text('Citas content')),
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
