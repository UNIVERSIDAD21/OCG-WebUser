import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/widgets/ocg_segmented_tabs.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/components/section_panel.dart';
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
          embeddedInAdminMobileShell: widget.embeddedInAdminMobileShell,
          onDelete: _deleting ? null : () => _deletePatient(patient),
        );
      },
    );
  }
}

enum _TreatmentSubView { hub, payments, documents }

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
      'tratamiento' ||
      'tratamientos' ||
      'pagos' ||
      'docs' ||
      'documentos' ||
      'historial' => 1,
      'citas' => 2,
      'simulador' => 3,
      _ => 0,
    };
    final initialTreatmentSubView = switch (sectionParam) {
      'pagos' => _TreatmentSubView.payments,
      'docs' || 'documentos' || 'historial' => _TreatmentSubView.documents,
      _ => _TreatmentSubView.hub,
    };

    final content = _AdminPatientWorkspace(
      patient: patient,
      embeddedInAdminMobileShell: embeddedInAdminMobileShell,
      initialSection: initialMobileSection,
      initialTreatmentSubView: initialTreatmentSubView,
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
        'tratamientos' ||
        'pagos' ||
        'docs' ||
        'documentos' ||
        'historial' => 1,
        'citas' => 2,
        'simulador' => 3,
        _ => 0,
      };

      final desktopContent = DefaultTabController(
        length: 4,
        initialIndex: initialDesktopTab,
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
                        SizedBox(height: sectionGap),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tier == AdminDesktopTier.tight
                                ? 10
                                : 12,
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
                              Tab(text: 'Citas'),
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
                          _DesktopTreatmentModule(
                            patient: patient,
                            initialSubView: initialTreatmentSubView,
                          ),
                          PatientAppointmentsTab(patient: patient),
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
    required this.embeddedInAdminMobileShell,
    required this.onEdit,
    required this.onDelete,
    this.initialSection = 0,
    this.initialTreatmentSubView = _TreatmentSubView.hub,
  });

  final PatientModel patient;
  final bool embeddedInAdminMobileShell;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int initialSection;
  final _TreatmentSubView initialTreatmentSubView;

  @override
  ConsumerState<_AdminPatientWorkspace> createState() =>
      _AdminPatientWorkspaceState();
}

class _AdminPatientWorkspaceState
    extends ConsumerState<_AdminPatientWorkspace> {
  late int _section;
  late _TreatmentSubView _treatmentSubView;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 3);
    _treatmentSubView = widget.initialTreatmentSubView;
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
      2 => PatientAppointmentsTab(patient: widget.patient, scrollable: false),
      3 => PatientSimulatorTab(patient: widget.patient, scrollable: false),
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
        OcgSegmentedTabItem(
          value: 2,
          label: 'Citas',
          icon: Icons.calendar_month_outlined,
          badge: appointmentsCount == 0 ? null : '$appointmentsCount',
        ),
        OcgSegmentedTabItem(
          value: 3,
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
      1 => _buildTreatmentModuleSection(
        treatments: treatments,
        nextAppointment: nextAppointment,
        paymentsResolution: paymentsResolution,
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
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildTreatmentModuleSection({
    required List<PatientTreatment> treatments,
    required AppointmentModel? nextAppointment,
    required EffectivePatientDataResolution paymentsResolution,
  }) {
    return AnimatedSwitcher(
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
        key: ValueKey(_treatmentSubView),
        child: switch (_treatmentSubView) {
          _TreatmentSubView.hub => _buildTreatmentsHubSection(
            treatments: treatments,
            nextAppointment: nextAppointment,
            paymentsResolution: paymentsResolution,
          ),
          _TreatmentSubView.payments => _buildTreatmentPaymentsSubview(
            treatments: treatments,
            paymentsResolution: paymentsResolution,
          ),
          _TreatmentSubView.documents => _buildTreatmentDocumentsSubview(),
        },
      ),
    );
  }

  Widget _buildTreatmentsHubSection({
    required List<PatientTreatment> treatments,
    required AppointmentModel? nextAppointment,
    required EffectivePatientDataResolution paymentsResolution,
  }) {
    final legacyOnly =
        treatments.isNotEmpty &&
        treatments.every((item) => item.id.startsWith('legacy-primary-'));
    final activeTreatment = _resolvePrimaryTreatment(treatments);
    final pending = paymentsResolution.paymentAccounts.fold<double>(
      0.0,
      (sum, item) => sum + item.payment.saldoPendiente,
    );
    final paid = paymentsResolution.paymentAccounts.fold<double>(
      0.0,
      (sum, item) => sum + item.payment.montoPagado,
    );
    final summaryText = treatments.isEmpty
        ? 'Aún no hay tratamientos registrados. Mantén pagos y documentos clínicos centralizados cuando el plan esté listo.'
        : legacyOnly
        ? 'Tratamiento principal migrado desde datos legacy.'
        : '${treatments.length} tratamiento${treatments.length == 1 ? '' : 's'} con pagos y documentos asociados.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTreatmentPremiumHero(
          activeTreatment: activeTreatment,
          treatmentsCount: treatments.length,
          summaryText: summaryText,
          pending: pending,
          paid: paid,
        ),
        const SizedBox(height: 12),
        if (activeTreatment != null) ...[
          _buildTreatmentAlertStrip(activeTreatment, pending, nextAppointment),
          const SizedBox(height: 12),
          _buildMobileTreatmentTimeline(activeTreatment),
          const SizedBox(height: 12),
          _buildTreatmentActionPanel(activeTreatment),
          const SizedBox(height: 12),
        ] else ...[
          _buildEmptyTreatmentActionPanel(),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _treatmentAccessCard(
                title: 'Pagos',
                subtitle: paymentsResolution.paymentAccounts.isEmpty
                    ? 'Sin cuentas activas'
                    : '${paymentsResolution.paymentAccounts.length} cuenta${paymentsResolution.paymentAccounts.length == 1 ? '' : 's'} · pendiente ${_money(pending)}',
                metric: 'Pagado ${_money(paid)}',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => _openTreatmentSubview(_TreatmentSubView.payments),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _treatmentAccessCard(
                title: 'Documentos',
                subtitle: 'Archivos clínicos, radiografías y soportes',
                metric: 'Documentos clínicos',
                icon: Icons.folder_open_outlined,
                onTap: () => _openTreatmentSubview(_TreatmentSubView.documents),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (treatments.isNotEmpty)
          for (final treatment in treatments) ...[
            _buildTreatmentListCard(treatment),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildTreatmentPaymentsSubview({
    required List<PatientTreatment> treatments,
    required EffectivePatientDataResolution paymentsResolution,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _treatmentSubviewHeader(
          title: 'Pagos del tratamiento',
          subtitle: 'Estado financiero del paciente dentro del módulo clínico.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 12),
        _buildMobilePaymentsSection(
          treatments: treatments,
          paymentsResolution: paymentsResolution,
        ),
      ],
    );
  }

  Widget _buildTreatmentDocumentsSubview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _treatmentSubviewHeader(
          title: 'Documentos clínicos',
          subtitle:
              'Archivos, radiografías y soportes asociados al tratamiento.',
          icon: Icons.folder_open_outlined,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
          ),
          child: PatientClinicalHistoryTab(
            patientId: widget.patient.id,
            patient: widget.patient,
            scrollable: false,
          ),
        ),
      ],
    );
  }

  Widget _treatmentSubviewHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return _patientCard(
      title: title,
      icon: icon,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            onPressed: _backToTreatmentHub,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a tratamientos',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: OcgColors.bronze,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La flecha vuelve al hub de Tratamientos sin salir del detalle del paciente.',
                  style: TextStyle(color: OcgColors.ink, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentPremiumHero({
    required PatientTreatment? activeTreatment,
    required int treatmentsCount,
    required String summaryText,
    required double pending,
    required double paid,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3527), Color(0xFF9A7654)],
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: OcgColors.ivory,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tratamientos',
                      style: TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summaryText,
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.82),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeTreatment == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OcgColors.ivory.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OcgColors.ivory.withOpacity(0.18)),
              ),
              child: const Text(
                'Estado vacío: aún no hay tratamiento activo o principal para resumir.',
                style: TextStyle(
                  color: OcgColors.ivory,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            Text(
              activeTreatment.displayName,
              style: const TextStyle(
                color: OcgColors.ivory,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _treatmentHeroChip(
                  activeTreatment.isPrimary ? 'Principal' : 'Secundario',
                  Icons.star_border,
                ),
                _treatmentHeroChip(
                  activeTreatment.statusLabel,
                  Icons.favorite_border,
                ),
                _treatmentHeroChip(
                  activeTreatment.currentStageName,
                  Icons.timeline_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _treatmentHeroMetric(
                    'Tratamientos',
                    treatmentsCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _treatmentHeroMetric('Pagado', _money(paid))),
                const SizedBox(width: 8),
                Expanded(
                  child: _treatmentHeroMetric('Pendiente', _money(pending)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _treatmentHeroChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: OcgColors.ivory),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treatmentHeroMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: OcgColors.ivory.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentAlertStrip(
    PatientTreatment treatment,
    double globalPending,
    AppointmentModel? nextAppointment,
  ) {
    final alerts = <({IconData icon, String text, Color color})>[];
    if (nextAppointment == null && !treatment.isFinished) {
      alerts.add((
        icon: Icons.event_busy_outlined,
        text: 'Sin próxima cita registrada para seguimiento clínico.',
        color: const Color(0xFF8A5A00),
      ));
    }
    if (treatment.isFinished) {
      alerts.add((
        icon: Icons.check_circle_outline,
        text:
            'Tratamiento marcado como ${treatment.statusLabel.toLowerCase()}.',
        color: const Color(0xFF2E7D32),
      ));
    }
    if ((treatment.saldoPendiente ?? globalPending) > 0) {
      alerts.add((
        icon: Icons.account_balance_wallet_outlined,
        text: 'Saldo pendiente asociado al módulo clínico.',
        color: OcgColors.bronze,
      ));
    }
    if (treatment.fechaFin == null && !treatment.isFinished) {
      alerts.add((
        icon: Icons.flag_outlined,
        text: 'Sin fecha estimada de finalización registrada.',
        color: const Color(0xFF8A5A00),
      ));
    }
    if ((treatment.notas ?? '').trim().isEmpty) {
      alerts.add((
        icon: Icons.notes_outlined,
        text: 'Sin notas clínicas para este tratamiento.',
        color: OcgColors.bronze,
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.take(3).map((alert) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alert.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alert.color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Icon(alert.icon, color: alert.color, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.text,
                  style: TextStyle(
                    color: alert.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyTreatmentActionPanel() {
    return _patientCard(
      title: 'Acciones del tratamiento',
      icon: Icons.flash_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: () => _openManageTreatmentDialog(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Crear primer tratamiento'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Crea el tratamiento inicial para activar etapa clínica, pagos asociados y documentos del módulo.',
            style: TextStyle(
              color: OcgColors.bronze,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentActionPanel(PatientTreatment treatment) {
    final canUpdateStage = !treatment.isFinished;

    return _patientCard(
      title: 'Acciones del tratamiento',
      icon: Icons.flash_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: canUpdateStage
                    ? () => _openUpdateStageDialog(treatment)
                    : null,
                icon: const Icon(Icons.trending_up_outlined, size: 18),
                label: const Text('Actualizar etapa'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openManageTreatmentDialog(treatment),
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Editar tratamiento'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openManageTreatmentDialog(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Nuevo tratamiento'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _openTreatmentSubview(_TreatmentSubView.payments),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pagos'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _openTreatmentSubview(_TreatmentSubView.documents),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Documentos'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            canUpdateStage
                ? 'Las acciones se mantienen dentro del módulo de Tratamientos para no sacar al admin del detalle móvil.'
                : 'Este tratamiento ya está ${treatment.statusLabel.toLowerCase()}; la etapa no se puede actualizar desde esta acción rápida.',
            style: const TextStyle(
              color: OcgColors.bronze,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildMobileTreatmentTimeline(PatientTreatment treatment) {
    final stages = TreatmentStage.values;
    final currentIndex = stages.indexOf(treatment.etapaActual);

    return _patientCard(
      title: 'Progreso clínico',
      icon: Icons.timeline_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa actual: ${treatment.currentStageName}',
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < stages.length; index++) ...[
                  _buildMiniStageChip(
                    label: stageNames[stages[index]] ?? stages[index].name,
                    completed: index < currentIndex,
                    active: index == currentIndex,
                  ),
                  if (index != stages.length - 1)
                    Container(
                      width: 18,
                      height: 2,
                      color: index < currentIndex
                          ? OcgColors.espresso
                          : OcgColors.bronze.withOpacity(0.22),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _mobileMetricRow('Inicio', _date(treatment.fechaInicio)),
          _mobileMetricRow(
            'Fin estimado',
            treatment.fechaFin == null
                ? 'Sin fecha estimada'
                : _date(treatment.fechaFin!),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStageChip({
    required String label,
    required bool completed,
    required bool active,
  }) {
    final color = active
        ? OcgColors.espresso
        : completed
        ? const Color(0xFF2E7D32)
        : OcgColors.bronze;
    return Container(
      width: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(active ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(active ? 0.30 : 0.16)),
      ),
      child: Column(
        children: [
          Icon(
            completed
                ? Icons.check_circle
                : active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _treatmentAccessCard({
    required String title,
    required String subtitle,
    required String metric,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OcgColors.espresso,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: OcgColors.ivory, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: OcgColors.ink, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              metric,
              style: const TextStyle(
                color: OcgColors.bronze,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PatientTreatment? _resolvePrimaryTreatment(
    List<PatientTreatment> treatments,
  ) {
    for (final treatment in treatments) {
      if (treatment.isPrimary) return treatment;
    }
    if (treatments.isEmpty) return null;
    return treatments.first;
  }

  Widget _buildMobilePaymentsSection({
    required List<PatientTreatment> treatments,
    required EffectivePatientDataResolution paymentsResolution,
  }) {
    double total = 0.0;
    double paid = 0.0;
    double pending = 0.0;

    for (final EffectivePatientPaymentAccount account
        in paymentsResolution.paymentAccounts) {
      total += account.payment.totalTratamiento;
      paid += account.payment.montoPagado;
      pending += account.payment.saldoPendiente;
    }

    final transactions = paymentsResolution.transactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _patientCard(
          title: 'Resumen global de pagos',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mobileMetricRow('Total del paciente', _money(total)),
              _mobileMetricRow('Total pagado', _money(paid)),
              _mobileMetricRow('Saldo pendiente', _money(pending)),
              _mobileMetricRow(
                'Cuentas activas',
                paymentsResolution.paymentAccounts.isEmpty
                    ? 'Sin cuentas'
                    : '${paymentsResolution.paymentAccounts.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _patientCard(
          title: 'Cuentas por tratamiento',
          icon: Icons.layers_outlined,
          child: paymentsResolution.paymentAccounts.isEmpty
              ? const Text(
                  'No hay cuentas de pago registradas todavía.',
                  style: TextStyle(color: OcgColors.ink),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final account
                        in paymentsResolution.paymentAccounts) ...[
                      _buildMobilePaymentAccountCard(
                        account: account,
                        treatment: _resolveTreatmentForAccount(
                          treatments,
                          account,
                        ),
                        allTransactions: transactions,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _patientCard(
          title: 'Historial reciente',
          icon: Icons.receipt_long_outlined,
          child: transactions.isEmpty
              ? const Text(
                  'No hay pagos registrados para este paciente.',
                  style: TextStyle(color: OcgColors.ink),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tx in transactions.take(8)) ...[
                      _buildMobileTransactionCard(
                        tx,
                        _resolveTreatmentForTransaction(
                          treatments,
                          paymentsResolution.paymentAccounts,
                          tx,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
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
            onTap: () => _openTreatmentSubview(_TreatmentSubView.payments),
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

  Widget _buildTreatmentListCard(PatientTreatment treatment) {
    final note = treatment.notas?.trim();
    final isLegacy = treatment.id.startsWith('legacy-primary-');
    final roleLabel = treatment.isPrimary || isLegacy
        ? 'Principal'
        : 'Secundario';
    final currentIndex = TreatmentStage.values.indexOf(treatment.etapaActual);
    final stageProgress = TreatmentStage.values.length <= 1
        ? 1.0
        : (currentIndex + 1) / TreatmentStage.values.length;
    final pending = treatment.saldoPendiente ?? 0;
    final total = treatment.totalTratamiento ?? 0;
    final statusColor = treatment.isFinished
        ? const Color(0xFF2E7D32)
        : treatment.isActive
        ? OcgColors.espresso
        : OcgColors.bronze;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: treatment.isPrimary
              ? OcgColors.espresso.withOpacity(0.24)
              : OcgColors.bronze.withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(
              treatment.isPrimary ? 0.08 : 0.04,
            ),
            blurRadius: treatment.isPrimary ? 18 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  treatment.isFinished
                      ? Icons.check_circle_outline
                      : Icons.monitor_heart_outlined,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treatment.displayName,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusBadge(roleLabel),
                        _statusBadge(treatment.statusLabel),
                        _statusBadge(treatment.currentStageName),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: stageProgress.clamp(0.0, 1.0),
              backgroundColor: OcgColors.bronze.withOpacity(0.14),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Progreso clínico ${(stageProgress * 100).round()}% · ${treatment.currentStageName}',
            style: const TextStyle(
              color: OcgColors.bronze,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _treatmentListMetric(
                  'Inicio',
                  _date(treatment.fechaInicio),
                  Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _treatmentListMetric(
                  'Valor',
                  total <= 0 ? 'Sin valor' : _money(total),
                  Icons.attach_money_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _treatmentListMetric(
                  'Pendiente',
                  pending <= 0 ? 'Al día' : _money(pending),
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _treatmentListMetric(
                  'Control',
                  treatment.nextControlDate == null
                      ? 'Sin fecha'
                      : _date(treatment.nextControlDate!),
                  Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F3ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: Text(
                note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OcgColors.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: treatment.isFinished
                    ? null
                    : () => _openUpdateStageDialog(treatment),
                icon: const Icon(Icons.trending_up_outlined, size: 18),
                label: const Text('Etapa'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openManageTreatmentDialog(treatment),
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _openTreatmentSubview(_TreatmentSubView.payments),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pagos'),
              ),
              OutlinedButton.icon(
                onPressed: note == null || note.isEmpty
                    ? null
                    : () => _showTreatmentNotes(treatment),
                icon: const Icon(Icons.notes_outlined, size: 18),
                label: const Text('Notas'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _treatmentListMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: OcgColors.bronze, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OcgColors.bronze,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
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
      _section = index.clamp(0, 3);
      if (_section != 1) {
        _treatmentSubView = _TreatmentSubView.hub;
      }
    });
  }

  void _openTreatmentSubview(_TreatmentSubView subView) {
    setState(() {
      _section = 1;
      _treatmentSubView = subView;
    });
  }

  void _backToTreatmentHub() {
    setState(() => _treatmentSubView = _TreatmentSubView.hub);
  }

  String _money(num value) => '\$${formatCop(value)}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _DesktopTreatmentModule extends StatefulWidget {
  const _DesktopTreatmentModule({
    required this.patient,
    required this.initialSubView,
  });

  final PatientModel patient;
  final _TreatmentSubView initialSubView;

  @override
  State<_DesktopTreatmentModule> createState() =>
      _DesktopTreatmentModuleState();
}

class _DesktopTreatmentModuleState extends State<_DesktopTreatmentModule> {
  late _TreatmentSubView _subView;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subView = widget.initialSubView;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setSubView(_TreatmentSubView subView) {
    setState(() => _subView = subView);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 12, bottom: 24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_subView),
            child: switch (_subView) {
              _TreatmentSubView.hub => _buildHub(),
              _TreatmentSubView.payments => _buildSubview(
                title: 'Pagos del tratamiento',
                subtitle:
                    'Estado financiero del paciente dentro del módulo clínico.',
                icon: Icons.account_balance_wallet_outlined,
                child: PatientPaymentsTab(
                  patientId: widget.patient.id,
                  scrollable: false,
                ),
              ),
              _TreatmentSubView.documents => _buildSubview(
                title: 'Documentos clínicos',
                subtitle:
                    'Archivos, radiografías y soportes asociados al tratamiento.',
                icon: Icons.folder_open_outlined,
                child: PatientClinicalHistoryTab(
                  patientId: widget.patient.id,
                  patient: widget.patient,
                  scrollable: false,
                ),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHub() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Módulo de tratamientos',
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tratamiento, pagos y documentos clínicos quedan integrados en una sola experiencia.',
                style: TextStyle(color: OcgColors.bronze),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DesktopTreatmentAccessCard(
                      title: 'Pagos',
                      subtitle: 'Resumen financiero y cuentas del tratamiento',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _setSubView(_TreatmentSubView.payments),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DesktopTreatmentAccessCard(
                      title: 'Documentos clínicos',
                      subtitle:
                          'Archivos, radiografías y soportes del paciente',
                      icon: Icons.folder_open_outlined,
                      onTap: () => _setSubView(_TreatmentSubView.documents),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PatientTreatmentTab(
          patientId: widget.patient.id,
          patient: widget.patient,
          scrollable: false,
        ),
      ],
    );
  }

  Widget _buildSubview({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => _setSubView(_TreatmentSubView.hub),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver a tratamientos',
              ),
              const SizedBox(width: 12),
              Icon(icon, color: OcgColors.espresso),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: OcgColors.bronze),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DesktopTreatmentAccessCard extends StatelessWidget {
  const _DesktopTreatmentAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F3ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OcgColors.espresso,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: OcgColors.ivory),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: OcgColors.ink)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: OcgColors.bronze),
          ],
        ),
      ),
    );
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
