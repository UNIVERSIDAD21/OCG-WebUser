import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../../shared/widgets/ocg_chip.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile_photo/providers/profile_photo_provider.dart';
import 'admin_mobile_shell_controller.dart';

class AdminPatientsScreen extends ConsumerStatefulWidget {
  const AdminPatientsScreen({super.key, this.embeddedInMobileShell = false});

  final bool embeddedInMobileShell;

  @override
  ConsumerState<AdminPatientsScreen> createState() =>
      _AdminPatientsScreenState();

  static const _legacyDesktopFilters = <String>[
    'Todos',
    'Pendientes',
    'Activos',
    'Alta',
    'Convencional',
    'Estetico',
    'Autoligado',
    'Alineadores',
    'Ortopedia',
    'Retenedores',
  ];

  static const _mobileFilters = <String>[
    'Todos',
    'Sin seguimiento',
    'Con saldo',
    'Cita próxima',
    'Nuevos',
    'Sin tratamiento',
  ];

  static Future<void> showAddPatientDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String password = '';
    String confirmPassword = '';
    bool submitting = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDs) => AlertDialog(
          title: const Text('Agregar paciente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: Validators.fullName,
                    onSaved: (v) => fullName = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                    onSaved: (v) => email = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña temporal',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: Validators.passwordForRegister,
                    onChanged: (v) => password = v,
                    onSaved: (v) => password = v ?? '',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => Validators.confirmPassword(v, password),
                    onChanged: (v) => confirmPassword = v,
                    onSaved: (v) => confirmPassword = v ?? '',
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'El tratamiento se configurará después desde el perfil del paciente.',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: OcgColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      formKey.currentState!.save();

                      if (confirmPassword != password) {
                        setDs(() => formError = 'Las contraseñas no coinciden');
                        return;
                      }

                      setDs(() {
                        submitting = true;
                        formError = null;
                      });

                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .createPatientByAdmin(
                              email: email,
                              password: password,
                              displayName: fullName,
                            );
                        ref.invalidate(patientsStreamProvider);
                        ref.invalidate(filteredPatientsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paciente creado correctamente.'),
                            ),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } on FirebaseAuthException catch (e) {
                        setDs(() {
                          submitting = false;
                          formError = e.code == 'email-already-in-use'
                              ? 'Este correo ya está en uso.'
                              : 'No se pudo crear la cuenta [${e.code}].';
                        });
                      } on FirebaseFunctionsException catch (e) {
                        setDs(() {
                          submitting = false;
                          formError = e.code == 'already-exists'
                              ? 'Este correo ya está en uso.'
                              : (e.message ?? 'No se pudo crear la cuenta.');
                        });
                      } on FirebaseException catch (e) {
                        setDs(() {
                          submitting = false;
                          final code = e.code.toLowerCase();
                          formError =
                              code.contains('already') ||
                                  code.contains('in-use')
                              ? 'Este correo ya está en uso.'
                              : (e.message ??
                                    'No se pudo crear la cuenta. Intenta de nuevo.');
                        });
                      } catch (_) {
                        setDs(() {
                          submitting = false;
                          formError =
                              'No se pudo crear la cuenta. Intenta de nuevo.';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPatientsScreenState extends ConsumerState<AdminPatientsScreen> {
  final TextEditingController _mobileSearchController = TextEditingController();
  String _mobileFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _mobileSearchController.text = ref.read(patientsSearchQueryProvider);
  }

  @override
  void dispose() {
    _mobileSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta de nuevo.'),
        ),
      );
    }
  }

  Widget _buildMobileBody({
    required BuildContext context,
    required AsyncValue<List<PatientModel>> asyncPatients,
    required List<AppointmentModel> appointments,
    required String query,
  }) {
    return Column(
      children: [
        Expanded(
          child: asyncPatients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No se pudo cargar pacientes: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (patients) {
              final insights = _buildPatientInsights(patients, appointments);
              final visible = _filterMobilePatients(
                insights,
                query,
                _mobileFilter,
              );
              final withoutFollowUp = insights
                  .where((e) => e.noFollowUp)
                  .length;
              final withBalance = insights.where((e) => e.hasBalance).length;
              final subtitle = query.isNotEmpty || _mobileFilter != 'Todos'
                  ? '${visible.length} resultados encontrados'
                  : '${patients.length} registrados · $withoutFollowUp sin seguimiento';

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _MobilePatientsHeader(
                      subtitle: subtitle,
                      controller: _mobileSearchController,
                      hasQuery: query.isNotEmpty,
                      onChanged: (value) => ref
                          .read(patientsSearchQueryProvider.notifier)
                          .setQuery(value),
                      onClear: () {
                        _mobileSearchController.clear();
                        ref
                            .read(patientsSearchQueryProvider.notifier)
                            .setQuery('');
                      },
                      actions: [
                        _AdminMobileNotificationsAction(ref: ref),
                        const SizedBox(width: 6),
                        _AdminMobileProfileAction(ref: ref),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MobileClinicalFilters(
                            selected: _mobileFilter,
                            onSelected: (value) =>
                                setState(() => _mobileFilter = value),
                          ),
                          const SizedBox(height: 10),
                          _MobilePatientSummaryStrip(
                            total: patients.length,
                            withoutFollowUp: withoutFollowUp,
                            withBalance: withBalance,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MobilePatientsEmptyState(
                        hasPatients: patients.isNotEmpty,
                        hasQuery: query.isNotEmpty,
                        filter: _mobileFilter,
                        onAdd: () => AdminPatientsScreen.showAddPatientDialog(
                          context,
                          ref,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final insight = visible[index];
                          return _PatientCard(
                            insight: insight,
                            onTap: () => _openPatient(context, insight.patient),
                            onOpen: () =>
                                _openPatient(context, insight.patient),
                            onCita: () => _openPatientSection(
                              context,
                              insight.patient,
                              'citas',
                            ),
                            onPagos: () => _openPatientSection(
                              context,
                              insight.patient,
                              'pagos',
                            ),
                            onTratamiento: () => _openPatientSection(
                              context,
                              insight.patient,
                              'tratamiento',
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<_PatientFollowUpStatus> _buildPatientInsights(
    List<PatientModel> patients,
    List<AppointmentModel> appointments,
  ) {
    final now = DateTime.now();
    final byPatient = <String, List<AppointmentModel>>{};
    for (final appt in appointments) {
      if (appt.patientId.isEmpty) continue;
      byPatient.putIfAbsent(appt.patientId, () => []).add(appt);
    }

    final items =
        patients
            .map(
              (patient) => _calculatePatientPriority(
                patient: patient,
                appointments:
                    byPatient[patient.id] ?? const <AppointmentModel>[],
                now: now,
              ),
            )
            .toList()
          ..sort((a, b) {
            final priority = b.priority.compareTo(a.priority);
            if (priority != 0) return priority;
            return a.patient.nombre.toLowerCase().compareTo(
              b.patient.nombre.toLowerCase(),
            );
          });

    return items;
  }

  List<_PatientFollowUpStatus> _filterMobilePatients(
    List<_PatientFollowUpStatus> insights,
    String query,
    String filter,
  ) {
    final q = query.trim().toLowerCase();

    bool matchesQuery(_PatientFollowUpStatus item) {
      if (q.isEmpty) return true;
      final p = item.patient;
      return p.nombre.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          p.telefono.toLowerCase().contains(q);
    }

    bool matchesFilter(_PatientFollowUpStatus item) {
      return switch (filter) {
        'Sin seguimiento' => item.noFollowUp,
        'Con saldo' => item.hasBalance,
        'Cita próxima' => item.hasUpcomingAppointment,
        'Nuevos' => item.isNew,
        'Sin tratamiento' => item.noTreatment,
        _ => true,
      };
    }

    return insights
        .where((item) => matchesQuery(item) && matchesFilter(item))
        .toList();
  }

  void _openPatient(BuildContext context, PatientModel patient) {
    context.go(
      RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id),
    );
  }

  void _openPatientSection(
    BuildContext context,
    PatientModel patient,
    String section,
  ) {
    context.go(
      '${RouteNames.adminPatientDetail.replaceFirst(':patientId', patient.id)}?section=$section',
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncPatients = ref.watch(patientsStreamProvider);
    final loading = ref.watch(authNotifierProvider).isLoading;
    final filteredPatients = ref.watch(filteredPatientsProvider);
    final selectedFilter = ref.watch(patientsFilterProvider);

    final query = ref.watch(patientsSearchQueryProvider).trim();
    final appointments =
        ref.watch(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    final mobileBody = _buildMobileBody(
      context: context,
      asyncPatients: asyncPatients,
      appointments: appointments,
      query: query,
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      final now = DateTime.now();
      final totalPacientes = filteredPatients.length;
      final pacientesActivos = filteredPatients
          .where((p) => p.etapaActual != TreatmentStage.alta)
          .length;
      final citasHoy = filteredPatients.where((p) {
        final cita = p.proximaCita;
        if (cita == null) return false;
        return cita.year == now.year &&
            cita.month == now.month &&
            cita.day == now.day;
      }).length;
      final saldoPendienteTotal = filteredPatients.fold<double>(
        0,
        (acc, p) => acc + p.saldoPendiente,
      );
      final nuevosMes = filteredPatients.where((p) {
        final created = p.createdAt;
        if (created == null) return false;
        return created.year == now.year && created.month == now.month;
      }).length;

      final layout = AdminDesktopLayoutScope.maybeOf(context);
      final tier = layout?.tier ?? AdminDesktopTier.standard;
      final sectionGap = layout?.sectionSpacing ?? 16;
      final panelGap = layout?.panelGap ?? 16;
      final headerTitleSize = switch (tier) {
        AdminDesktopTier.wide => 32.0,
        AdminDesktopTier.standard => 30.0,
        AdminDesktopTier.compact => 28.0,
        AdminDesktopTier.tight => 26.0,
      };

      final desktopContent = Padding(
        padding: EdgeInsets.only(bottom: sectionGap + 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes',
                        style: TextStyle(
                          fontSize: headerTitleSize,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2016),
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Gestión clínica y financiera',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A735C),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2016),
                    foregroundColor: OcgColors.ivory,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () =>
                      AdminPatientsScreen.showAddPatientDialog(context, ref),
                  icon: const Icon(
                    Icons.person_add_outlined,
                    size: 16,
                    color: Color(0xFFC9A882),
                  ),
                  label: const Text('Nuevo paciente'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            _KpiRow(
              totalPacientes: totalPacientes,
              pacientesActivos: pacientesActivos,
              citasHoy: citasHoy,
              saldoPendienteTotal: saldoPendienteTotal,
              nuevosMes: nuevosMes,
              onTapTotal: () {
                ref.read(patientsFilterProvider.notifier).setFilter('Todos');
                context.goAdminTab(1, RouteNames.adminPatients);
              },
              onTapActivos: () {
                ref.read(patientsFilterProvider.notifier).setFilter('Activos');
                context.goAdminTab(1, RouteNames.adminPatients);
              },
              onTapCitasHoy: () =>
                  context.goAdminTab(2, RouteNames.adminAppointments),
              onTapSaldoPendiente: () => context.go(RouteNames.adminPayments),
            ),
            SizedBox(height: panelGap),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tier == AdminDesktopTier.tight ? 12 : 14,
                vertical: tier == AdminDesktopTier.tight ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFFC9A882)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => ref
                          .read(patientsSearchQueryProvider.notifier)
                          .setQuery(value),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Buscar en pacientes ...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DDD2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.tune, size: 14, color: Color(0xFF9A735C)),
                        SizedBox(width: 6),
                        Text(
                          'Filtros',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A735C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: panelGap * 0.75),
            Wrap(
              spacing: tier == AdminDesktopTier.tight ? 6 : 8,
              runSpacing: tier == AdminDesktopTier.tight ? 6 : 8,
              children: AdminPatientsScreen._legacyDesktopFilters.map((filter) {
                final selected = filter == selectedFilter;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => ref
                      .read(patientsFilterProvider.notifier)
                      .setFilter(filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2C2016)
                          : const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF2C2016)
                            : const Color(0xFFE8DDD2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 12,
                            color: OcgColors.ivory,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? OcgColors.ivory
                                : const Color(0xFF7E6A5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: panelGap),
            Row(
              children: [
                const Text(
                  'Listado de pacientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2016),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE7),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFE2D0BC)),
                  ),
                  child: Text(
                    '${filteredPatients.length} registros',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A735C),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: panelGap * 0.75),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              padding: EdgeInsets.all(tier == AdminDesktopTier.tight ? 12 : 14),
              child: filteredPatients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No hay pacientes para los filtros actuales.',
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < filteredPatients.length; i++) ...[
                          _DesktopPatientRow(
                            patient: filteredPatients[i],
                            selected: false,
                            onTap: () => context.go(
                              RouteNames.adminPatientDetail.replaceFirst(
                                ':patientId',
                                filteredPatients[i].id,
                              ),
                            ),
                          ),
                          if (i != filteredPatients.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );

      return AdminWebShell(title: 'Pacientes', child: desktopContent);
    }

    if (widget.embeddedInMobileShell) {
      return mobileBody;
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 1, // Pacientes = índice 1
      title: 'Pacientes',
      showMobileAppBar: false,
      appBarActions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: loading ? null : () => _handleSignOut(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
      onSignOut: () => _handleSignOut(context, ref),
      railTrailing: OutlinedButton.icon(
        onPressed: loading ? null : () => _handleSignOut(context, ref),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD9D9),
          backgroundColor: OcgColors.error.withOpacity(0.14),
          side: BorderSide(color: const Color(0xFFFFD9D9).withOpacity(0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AdminPatientsScreen.showAddPatientDialog(context, ref),
        backgroundColor: OcgColors.bronze,
        child: const Icon(Icons.person_add),
      ),
      body: mobileBody,
    );
  }
}

// ─── _PatientCard ─────────────────────────────────────────────────────────────

String _fmtDate(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d/$m/${value.year}';
}

String _initialsFromName(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalPacientes,
    required this.pacientesActivos,
    required this.citasHoy,
    required this.saldoPendienteTotal,
    required this.nuevosMes,
    required this.onTapTotal,
    required this.onTapActivos,
    required this.onTapCitasHoy,
    required this.onTapSaldoPendiente,
  });

  final int totalPacientes;
  final int pacientesActivos;
  final int citasHoy;
  final double saldoPendienteTotal;
  final int nuevosMes;
  final VoidCallback onTapTotal;
  final VoidCallback onTapActivos;
  final VoidCallback onTapCitasHoy;
  final VoidCallback onTapSaldoPendiente;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final spacing = layout?.panelGap ?? 10;
    final cardWidth = switch (tier) {
      AdminDesktopTier.wide => 260.0,
      AdminDesktopTier.standard => 245.0,
      AdminDesktopTier.compact => 228.0,
      AdminDesktopTier.tight => 210.0,
    };

    final cards = [
      _KpiCard(
        icon: Icons.people_outline,
        value: '$totalPacientes',
        label: 'Total pacientes',
        footer: '+$nuevosMes este mes',
        footerColor: const Color(0xFF2E7D32),
        footerBg: const Color(0xFFE8F5E9),
        bgColor: const Color(0xFFF6EFE7),
        onTap: onTapTotal,
      ),
      _KpiCard(
        icon: Icons.timelapse_outlined,
        value: '$pacientesActivos',
        label: 'Activos',
        footer: 'en tratamiento',
        bgColor: const Color(0xFFEFF8F0),
        onTap: onTapActivos,
      ),
      _KpiCard(
        icon: Icons.calendar_month_outlined,
        value: '$citasHoy',
        label: 'Citas hoy',
        footer: 'programadas',
        bgColor: const Color(0xFFFFF4D8),
        onTap: onTapCitasHoy,
      ),
      _KpiCard(
        icon: Icons.attach_money,
        value: '\$${formatCop(saldoPendienteTotal)}',
        label: 'Saldo pendiente',
        footer: 'por cobrar',
        bgColor: const Color(0xFFFFECEC),
        onTap: onTapSaldoPendiente,
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) =>
            SizedBox(width: cardWidth, child: cards[index]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    this.footer,
    this.footerColor,
    this.footerBg,
    this.bgColor,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? footer;
  final Color? footerColor;
  final Color? footerBg;
  final Color? bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdminDesktopLayoutScope.maybeOf(context);
        final tier = layout?.tier ?? AdminDesktopTier.standard;
        final compact =
            tier == AdminDesktopTier.compact || tier == AdminDesktopTier.tight;
        final base = bgColor ?? OcgColors.ivory;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, Color.lerp(base, Colors.white, 0.35)!],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6D8CB), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142C2016),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              compact ? 8 : 10,
              compact ? 10 : 12,
              compact ? 8 : 10,
            ),
            child: Stack(
              children: [
                if (tier != AdminDesktopTier.tight)
                  Positioned(
                    top: -16,
                    right: -16,
                    child: Container(
                      width: compact ? 40 : 48,
                      height: compact ? 40 : 48,
                      decoration: BoxDecoration(
                        color: OcgColors.ivory.withOpacity(0.28),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 22 : 26,
                          height: compact ? 22 : 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x1A2C2016)),
                          ),
                          child: Icon(
                            icon,
                            size: compact ? 12 : 14,
                            color: const Color(0xFF9A735C),
                          ),
                        ),
                        const Spacer(),
                        if (tier != AdminDesktopTier.tight)
                          Container(
                            width: 18,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0x409A735C),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 5 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: compact ? 16 : 21,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2C2016),
                                    letterSpacing: -0.4,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2C2016),
                            ),
                          ),
                          if (footer != null &&
                              footer!.trim().isNotEmpty &&
                              tier != AdminDesktopTier.tight)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                footer!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 9 : 9.5,
                                  color: const Color(0xFF9A735C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopPatientRow extends StatelessWidget {
  const _DesktopPatientRow({
    required this.patient,
    required this.onTap,
    this.selected = false,
  });

  final PatientModel patient;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final stage = formatTreatmentStage(patient.etapaActual);
    final stageLower = stage.toLowerCase();
    final stageBg = stageLower.contains('valor')
        ? const Color(0xFFFFF3E0)
        : stageLower.contains('alta') || stageLower.contains('reten')
        ? const Color(0xFFE8F5E9)
        : OcgColors.mist;
    final stageFg = stageLower.contains('valor')
        ? const Color(0xFFE65100)
        : stageLower.contains('alta') || stageLower.contains('reten')
        ? const Color(0xFF2E7D32)
        : OcgColors.ink;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: OcgColors.ivory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OcgColors.bronze : OcgColors.sand,
            width: selected ? 1.3 : .7,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: OcgColors.bronze.withOpacity(.15),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: OcgColors.bronze.withOpacity(0.16),
              child: Text(
                _initialsFromName(patient.nombre),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OcgColors.espresso,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OcgColors.espresso,
                    ),
                  ),
                  Text(
                    patient.email,
                    style: TextStyle(
                      fontSize: 11,
                      color: OcgColors.ink.withOpacity(.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      OcgChip(
                        label: patient.tipoTratamiento?.name ?? 'Pendiente',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stageBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stage,
                          style: TextStyle(
                            fontSize: 10,
                            color: stageFg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${formatCop(patient.saldoPendiente)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OcgColors.espresso,
                  ),
                ),
                Text(
                  patient.proximaCita == null
                      ? 'Sin cita'
                      : _fmtDate(patient.proximaCita!),
                  style: TextStyle(
                    fontSize: 11,
                    color: OcgColors.ink.withOpacity(.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F0),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: OcgColors.bronze,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPatientsDesktopTestHarness extends StatelessWidget {
  const AdminPatientsDesktopTestHarness({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final sectionGap = layout?.sectionSpacing ?? 16;
    final panelGap = layout?.panelGap ?? 16;
    final headerTitleSize = switch (tier) {
      AdminDesktopTier.wide => 32.0,
      AdminDesktopTier.standard => 30.0,
      AdminDesktopTier.compact => 28.0,
      AdminDesktopTier.tight => 26.0,
    };

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: sectionGap + 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes',
                        style: TextStyle(
                          fontSize: headerTitleSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2C2016),
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gestión clínica y financiera',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A735C),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Nuevo paciente'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            _KpiRow(
              totalPacientes: 18,
              pacientesActivos: 12,
              citasHoy: 5,
              saldoPendienteTotal: 12500000,
              nuevosMes: 3,
              onTapTotal: () {},
              onTapActivos: () {},
              onTapCitasHoy: () {},
              onTapSaldoPendiente: () {},
            ),
            SizedBox(height: panelGap),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tier == AdminDesktopTier.tight ? 12 : 14,
                vertical: tier == AdminDesktopTier.tight ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 16, color: Color(0xFFC9A882)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Buscar en pacientes ...')),
                ],
              ),
            ),
            SizedBox(height: panelGap),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              padding: EdgeInsets.all(tier == AdminDesktopTier.tight ? 12 : 14),
              child: const Column(
                children: [
                  ListTile(title: Text('Paciente demo 1')),
                  SizedBox(height: 8),
                  ListTile(title: Text('Paciente demo 2')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PatientMobileCardStatus {
  overdue,
  noFollowUp,
  upcomingAppointment,
  newPatient,
  noTreatment,
  inTreatment,
}

class _PatientFollowUpStatus {
  const _PatientFollowUpStatus({
    required this.patient,
    required this.cardStatus,
    required this.lastActivity,
    required this.daysSinceLastActivity,
    required this.nextAppointment,
    required this.hasUpcomingAppointment,
    required this.hasBalance,
    required this.isPaymentOverdue,
    required this.noFollowUp,
    required this.isNew,
    required this.noTreatment,
    required this.priority,
    required this.clinicalLine,
    required this.highlights,
  });

  final PatientModel patient;
  final PatientMobileCardStatus cardStatus;
  final DateTime? lastActivity;
  final int? daysSinceLastActivity;
  final DateTime? nextAppointment;
  final bool hasUpcomingAppointment;
  final bool hasBalance;
  final bool isPaymentOverdue;
  final bool noFollowUp;
  final bool isNew;
  final bool noTreatment;
  final int priority;
  final String clinicalLine;
  final List<_PatientHighlight> highlights;
}

class _PatientHighlight {
  const _PatientHighlight({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;
}

_PatientFollowUpStatus _calculatePatientPriority({
  required PatientModel patient,
  required List<AppointmentModel> appointments,
  required DateTime now,
}) {
  final futureAppointments = appointments
      .where(
        (item) => _isActionableAppointment(item) && item.fechaHora.isAfter(now),
      )
      .map((item) => item.fechaHora)
      .toList();
  final patientNext = patient.proximaCita;
  if (patientNext != null && patientNext.isAfter(now)) {
    futureAppointments.add(patientNext);
  }
  futureAppointments.sort();
  final nextAppointment = futureAppointments.isEmpty
      ? null
      : futureAppointments.first;
  final hasUpcomingAppointment =
      nextAppointment != null &&
      nextAppointment.isBefore(now.add(const Duration(days: 7)));

  final lastActivity = _calculateLastActivity(
    patient: patient,
    appointments: appointments,
    now: now,
  );
  final daysSinceLastActivity = lastActivity == null
      ? null
      : now
            .difference(
              DateTime(lastActivity.year, lastActivity.month, lastActivity.day),
            )
            .inDays;

  final hasBalance = patient.saldoPendiente > 0;
  final isPaymentOverdue =
      hasBalance &&
      patient.fechaProximoPago != null &&
      patient.fechaProximoPago!.isBefore(now);
  final createdAt = patient.createdAt;
  final isNew =
      createdAt != null &&
      createdAt.isAfter(now.subtract(const Duration(days: 30)));
  final noTreatment = patient.tipoTratamiento == null;
  final noFollowUp =
      nextAppointment == null &&
      daysSinceLastActivity != null &&
      daysSinceLastActivity > 120;

  final cardStatus = isPaymentOverdue
      ? PatientMobileCardStatus.overdue
      : noFollowUp
      ? PatientMobileCardStatus.noFollowUp
      : hasUpcomingAppointment
      ? PatientMobileCardStatus.upcomingAppointment
      : isNew
      ? PatientMobileCardStatus.newPatient
      : noTreatment
      ? PatientMobileCardStatus.noTreatment
      : PatientMobileCardStatus.inTreatment;

  final priority = switch (cardStatus) {
    PatientMobileCardStatus.overdue => 100,
    PatientMobileCardStatus.noFollowUp => 90,
    PatientMobileCardStatus.upcomingAppointment => 72,
    PatientMobileCardStatus.noTreatment => 64,
    PatientMobileCardStatus.newPatient => 52,
    PatientMobileCardStatus.inTreatment => hasBalance ? 48 : 20,
  };

  final clinicalLine = noTreatment
      ? 'Sin tratamiento definido'
      : '${_tipoTratamientoLabel(patient.tipoTratamiento!)} · ${formatTreatmentStage(patient.etapaActual)}';

  final highlights = <_PatientHighlight>[];
  if (isPaymentOverdue) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.warning_amber_rounded,
        text: 'Saldo vencido: \$${formatCop(patient.saldoPendiente)}',
        color: OcgColors.error,
      ),
    );
  } else if (hasBalance) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.account_balance_wallet_outlined,
        text: 'Saldo pendiente: \$${formatCop(patient.saldoPendiente)}',
        color: const Color(0xFF9A5B2C),
      ),
    );
  }
  if (noFollowUp) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.priority_high_rounded,
        text: 'Sin seguimiento hace $daysSinceLastActivity días',
        color: const Color(0xFF9A735C),
      ),
    );
  }
  if (hasUpcomingAppointment) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.event_available_outlined,
        text: 'Cita ${_relativeAppointmentLabel(nextAppointment, now)}',
        color: const Color(0xFF2F6F9F),
      ),
    );
  }
  if (noTreatment) {
    highlights.add(
      const _PatientHighlight(
        icon: Icons.assignment_outlined,
        text: 'Completar plan clínico',
        color: Color(0xFF8A6F59),
      ),
    );
  }
  if (isNew) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.auto_awesome_outlined,
        text:
            'Nuevo · hace ${now.difference(createdAt).inDays.clamp(0, 30)} días',
        color: const Color(0xFF2E7D5B),
      ),
    );
  }
  if (highlights.isEmpty) {
    highlights.add(
      _PatientHighlight(
        icon: Icons.check_circle_outline,
        text: patient.nextSessionLabel,
        color: const Color(0xFF6F7A6B),
      ),
    );
  }

  return _PatientFollowUpStatus(
    patient: patient,
    cardStatus: cardStatus,
    lastActivity: lastActivity,
    daysSinceLastActivity: daysSinceLastActivity,
    nextAppointment: nextAppointment,
    hasUpcomingAppointment: hasUpcomingAppointment,
    hasBalance: hasBalance,
    isPaymentOverdue: isPaymentOverdue,
    noFollowUp: noFollowUp,
    isNew: isNew,
    noTreatment: noTreatment,
    priority: priority,
    clinicalLine: clinicalLine,
    highlights: highlights.take(2).toList(),
  );
}

DateTime? _calculateLastActivity({
  required PatientModel patient,
  required List<AppointmentModel> appointments,
  required DateTime now,
}) {
  final dates = <DateTime>[
    if (patient.updatedAt != null) patient.updatedAt!,
    if (patient.createdAt != null) patient.createdAt!,
    patient.fechaInicio,
    if (patient.proximaCita != null && patient.proximaCita!.isBefore(now))
      patient.proximaCita!,
  ];

  for (final appointment in appointments) {
    if (appointment.fechaHora.isBefore(now)) dates.add(appointment.fechaHora);
    if (appointment.updatedAt != null) dates.add(appointment.updatedAt!);
    if (appointment.createdAt != null) dates.add(appointment.createdAt!);
  }

  if (dates.isEmpty) return null;
  dates.sort();
  return dates.last;
}

bool _isActionableAppointment(AppointmentModel item) {
  return item.estado != AppointmentStatus.cancelada &&
      item.estado != AppointmentStatus.noAsistio;
}

class _MobilePatientsHeader extends StatelessWidget {
  const _MobilePatientsHeader({
    required this.subtitle,
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
    required this.actions,
  });

  final String subtitle;
  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 14,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B120C), Color(0xFF3A281B), OcgColors.espresso],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x242C2016),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pacientes',
                      style: TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.76),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: OcgColors.ivory.withOpacity(0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.36)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF8A6F59), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Buscar paciente...',
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: hasQuery
                      ? IconButton(
                          key: const ValueKey('clear-search'),
                          tooltip: 'Limpiar búsqueda',
                          visualDensity: VisualDensity.compact,
                          onPressed: onClear,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF8A6F59),
                          ),
                        )
                      : const SizedBox(key: ValueKey('no-search'), width: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileClinicalFilters extends StatelessWidget {
  const _MobileClinicalFilters({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: AdminPatientsScreen._mobileFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = AdminPatientsScreen._mobileFilters[index];
          final active = selected == filter;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? OcgColors.espresso : const Color(0xFFFFFDFC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? OcgColors.espresso : const Color(0xFFE5D4C4),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: OcgColors.espresso.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobilePatientSummaryStrip extends StatelessWidget {
  const _MobilePatientSummaryStrip({
    required this.total,
    required this.withoutFollowUp,
    required this.withBalance,
  });

  final int total;
  final int withoutFollowUp;
  final int withBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Text(
        '$total pacientes · $withoutFollowUp sin seguimiento · $withBalance con saldo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF8A6F59),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MobilePatientsEmptyState extends StatelessWidget {
  const _MobilePatientsEmptyState({
    required this.hasPatients,
    required this.hasQuery,
    required this.filter,
    required this.onAdd,
  });

  final bool hasPatients;
  final bool hasQuery;
  final String filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (!hasPatients) {
      return OcgEmptyState(
        icon: Icons.group_add_outlined,
        title: 'Aún no hay pacientes registrados',
        subtitle:
            'Agrega el primer paciente para iniciar su seguimiento clínico.',
        ctaLabel: 'Agregar paciente',
        onCta: onAdd,
      );
    }
    if (hasQuery) {
      return const OcgEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No encontramos pacientes',
        subtitle: 'Prueba con otro nombre, correo o teléfono.',
      );
    }
    return OcgEmptyState(
      icon: Icons.check_circle_outline,
      title: 'No hay pacientes ${filter.toLowerCase()}',
      subtitle: filter == 'Sin seguimiento'
          ? 'Todo está al día por ahora.'
          : 'No hay registros para este filtro clínico.',
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.insight,
    required this.onTap,
    required this.onOpen,
    required this.onCita,
    required this.onPagos,
    required this.onTratamiento,
  });

  final _PatientFollowUpStatus insight;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onCita;
  final VoidCallback onPagos;
  final VoidCallback onTratamiento;

  PatientModel get patient => insight.patient;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(insight.cardStatus);
    final primaryAction = insight.noFollowUp || insight.hasUpcomingAppointment
        ? ('Cita', onCita)
        : insight.hasBalance
        ? ('Pagos', onPagos)
        : insight.noTreatment
        ? ('Tratamiento', onTratamiento)
        : ('Ver', onOpen);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: statusStyle.borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142C2016),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfilePhotoAvatar(
                  label: patient.nombre,
                  photoUrl: patient.fotoUrl,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patient.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: OcgColors.espresso,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ClinicalStatusChip(style: statusStyle),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        insight.clinicalLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF7E6A5B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB59D87),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final highlight in insight.highlights) ...[
              _PatientHighlightRow(highlight: highlight),
              if (highlight != insight.highlights.last)
                const SizedBox(height: 6),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _CompactPatientAction(label: 'Ver', onTap: onOpen),
                const SizedBox(width: 8),
                _CompactPatientAction(
                  label: primaryAction.$1,
                  onTap: primaryAction.$2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalStatusChip extends StatelessWidget {
  const _ClinicalStatusChip({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.foregroundColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _PatientHighlightRow extends StatelessWidget {
  const _PatientHighlightRow({required this.highlight});

  final _PatientHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight.color ?? const Color(0xFF8A6F59);
    return Row(
      children: [
        Icon(highlight.icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            highlight.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactPatientAction extends StatelessWidget {
  const _CompactPatientAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5D4C4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: OcgColors.espresso,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
}

_StatusStyle _statusStyle(PatientMobileCardStatus status) {
  return switch (status) {
    PatientMobileCardStatus.overdue => const _StatusStyle(
      label: 'En mora',
      backgroundColor: Color(0xFFFFECEC),
      foregroundColor: OcgColors.error,
      borderColor: Color(0xFFFFD0D0),
    ),
    PatientMobileCardStatus.noFollowUp => const _StatusStyle(
      label: 'Sin seguimiento',
      backgroundColor: Color(0xFFFFF4E7),
      foregroundColor: Color(0xFF9A5B2C),
      borderColor: Color(0xFFE7C7A4),
    ),
    PatientMobileCardStatus.upcomingAppointment => const _StatusStyle(
      label: 'Cita próxima',
      backgroundColor: Color(0xFFEAF4FF),
      foregroundColor: Color(0xFF2F6F9F),
      borderColor: Color(0xFFC8DFF3),
    ),
    PatientMobileCardStatus.newPatient => const _StatusStyle(
      label: 'Nuevo',
      backgroundColor: Color(0xFFEAF7EF),
      foregroundColor: Color(0xFF2E7D5B),
      borderColor: Color(0xFFCDE8D7),
    ),
    PatientMobileCardStatus.noTreatment => const _StatusStyle(
      label: 'Sin tratamiento',
      backgroundColor: Color(0xFFF2EDE8),
      foregroundColor: Color(0xFF7E6A5B),
      borderColor: Color(0xFFE0D2C4),
    ),
    PatientMobileCardStatus.inTreatment => const _StatusStyle(
      label: 'En tratamiento',
      backgroundColor: Color(0xFFF6EFE7),
      foregroundColor: OcgColors.espresso,
      borderColor: Color(0xFFE5D4C4),
    ),
  };
}

String _relativeAppointmentLabel(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  final time = _fmtTime(date);
  if (diff == 0) return 'hoy $time';
  if (diff == 1) return 'mañana $time';
  return '${_fmtDate(date)} $time';
}

String _fmtTime(DateTime value) {
  final hour = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minute $suffix';
}

class _AdminMobileNotificationsAction extends ConsumerWidget {
  const _AdminMobileNotificationsAction({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final user = ref.watch(authStateProvider).asData?.value;
    final unread = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(user.uid));

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.push(RouteNames.adminNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: OcgColors.ivory),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: OcgColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminMobileProfileAction extends ConsumerWidget {
  const _AdminMobileProfileAction({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final user = ref.watch(authStateProvider).asData?.value;
    final label = _adminProfileLabel(user?.displayName, user?.email);
    final adminDoc = user == null
        ? null
        : ref.watch(adminProfileDocProvider(user.uid)).asData?.value;
    final photoUrl = resolveProfilePhotoUrl(adminDoc);

    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => context.goAdminTab(4, RouteNames.adminProfile),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: OcgColors.bronze,
          shape: BoxShape.circle,
        ),
        child: ProfilePhotoAvatar(label: label, photoUrl: photoUrl, radius: 17),
      ),
    );
  }
}

String _adminProfileLabel(String? displayName, String? email) {
  return (displayName?.trim().isNotEmpty == true)
      ? displayName!.trim()
      : (email?.trim().isNotEmpty == true ? email!.trim() : 'Administrador');
}

String _tipoTratamientoLabel(TreatmentType value) => switch (value) {
  TreatmentType.convencional => 'Convencional',
  TreatmentType.estetico => 'Brackets Estéticos',
  TreatmentType.autoligado => 'Autoligado',
  TreatmentType.alineadores => 'Alineadores',
  TreatmentType.ortopedia => 'Ortopedia',
  TreatmentType.retenedores => 'Retenedores',
  TreatmentType.interceptivo => 'Interceptivo',
};
