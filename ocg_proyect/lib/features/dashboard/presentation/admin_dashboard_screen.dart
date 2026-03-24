import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../admin/presentation/web/components/kpi_card.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/components/page_header.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _seedAvailability(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'seedAvailability',
      );
      await callable.call(<String, dynamic>{'days': 90});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilidad inicial creada para 90 días.'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'No se pudo inicializar disponibilidad.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo inicializar disponibilidad.')),
      );
    }
  }

  Future<void> _initializeAllPayments(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'initializeAllPaymentDocuments',
      );
      final result = await callable.call();
      final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
      final created = data['created'];
      final message =
          data['message']?.toString() ?? 'Inicialización completada.';

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message (creados: $created)')));
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo inicializar pagos.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo inicializar pagos.')),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de administrador?'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authNotifierProvider).isLoading;
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);

    final dashboardBody = _DashboardBody(
      ref: ref,
      onSignOut: () => _handleSignOut(context, ref),
      loading: loading,
      appointmentsAsync: appointmentsAsync,
      patientsAsync: patientsAsync,
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(
        currentRoute: RouteNames.adminDashboard,
        title: 'Dashboard',
        child: dashboardBody,
      );
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 0,
      title: 'Dashboard',
      appBarActions: [
        TextButton.icon(
          onPressed: () => _initializeAllPayments(context),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Inicializar pagos'),
        ),
        IconButton(
          tooltip: 'Inicializar disponibilidad (90 días)',
          onPressed: () => _seedAvailability(context),
          icon: const Icon(Icons.auto_awesome_motion_outlined),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: loading ? null : () => _handleSignOut(context, ref),
          icon: const Icon(Icons.logout, color: OcgColors.error),
        ),
      ],
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
      body: dashboardBody,
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.ref,
    required this.onSignOut,
    required this.loading,
    required this.appointmentsAsync,
    required this.patientsAsync,
  });

  final WidgetRef ref;
  final VoidCallback onSignOut;
  final bool loading;
  final AsyncValue<List<AppointmentModel>> appointmentsAsync;
  final AsyncValue<List<PatientModel>> patientsAsync;

  @override
  Widget build(BuildContext context) {
    final appointments =
        appointmentsAsync.asData?.value ?? const <AppointmentModel>[];
    final patients = patientsAsync.asData?.value ?? const <PatientModel>[];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final todaysAppointments =
        appointments
            .where(
              (a) =>
                  !a.fechaHora.isBefore(todayStart) &&
                  a.fechaHora.isBefore(tomorrowStart) &&
                  AppointmentsBusinessRules.shouldIncludeInDayAgenda(a.estado),
            )
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    final pendingConfirm = todaysAppointments
        .where((a) => a.estado == AppointmentStatus.programada)
        .length;

    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final canceladasSemana = appointments
        .where(
          (a) =>
              a.estado == AppointmentStatus.cancelada &&
              a.fechaHora.isAfter(sevenDaysAgo),
        )
        .length;

    final nuevosPacientes30d = patients
        .where(
          (p) =>
              p.createdAt != null &&
              p.createdAt!.isAfter(now.subtract(const Duration(days: 30))),
        )
        .length;

    final citasSinConfirmar2h = todaysAppointments
        .where(
          (a) =>
              a.estado == AppointmentStatus.programada &&
              a.fechaHora.isAfter(now) &&
              a.fechaHora.isBefore(now.add(const Duration(hours: 2))),
        )
        .length;

    final perfilesPendientes = patients
        .where((p) => p.tipoTratamiento == null || p.telefono.trim().isEmpty)
        .length;

    final pagosVencidos = patients
        .where(
          (p) =>
              p.saldoPendiente > 0 &&
              p.fechaProximoPago != null &&
              p.fechaProximoPago!.isBefore(todayStart),
        )
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Panel de control',
            subtitle: 'Resumen operativo del día en OCG Clínica',
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 680;
              return GridView.count(
                crossAxisCount: isCompact ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isCompact ? 1.4 : 1.7,
                children: [
                  KpiCard(
                    title: 'Citas hoy',
                    value: '${todaysAppointments.length}',
                    icon: Icons.today_outlined,
                  ),
                  KpiCard(
                    title: 'Citas Sin confirmar',
                    value: '$pendingConfirm',
                    icon: Icons.pending_actions_outlined,
                  ),
                  KpiCard(
                    title: 'Canceladas (7d)',
                    value: '$canceladasSemana',
                    icon: Icons.event_busy_outlined,
                  ),
                  KpiCard(
                    title: 'Pacientes nuevos(30d)',
                    value: '$nuevosPacientes30d',
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          const Text(
            'Acceso rápido',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _QuickCard(
                    icon: Icons.people_outline,
                    label: 'Pacientes',
                    onTap: () => context.go(RouteNames.adminPatients),
                  ),
                  _QuickCard(
                    icon: Icons.calendar_month_outlined,
                    label: 'Agenda',
                    onTap: () => context.go(RouteNames.adminAppointments),
                  ),
                  _QuickCard(
                    icon: Icons.person_add_outlined,
                    label: 'Nuevo paciente',
                    onTap: () => context.go(RouteNames.adminPatients),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          _AlertsCard(
            citasSinConfirmar2h: citasSinConfirmar2h,
            perfilesPendientes: perfilesPendientes,
            pagosVencidos: pagosVencidos,
          ),

          const SizedBox(height: 16),
          _TodayAgendaCard(
            ref: ref,
            loading: appointmentsAsync.isLoading,
            hasError: appointmentsAsync.hasError,
            appointments: todaysAppointments.take(8).toList(),
          ),

          const SizedBox(height: 24),
          const _SignOutButton(),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.24)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: OcgColors.bronze),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: OcgColors.ink.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.citasSinConfirmar2h,
    required this.perfilesPendientes,
    required this.pagosVencidos,
  });

  final int citasSinConfirmar2h;
  final int perfilesPendientes;
  final int pagosVencidos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas operativas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          _AlertRow(
            label: 'Citas en < 2h sin confirmar',
            value: citasSinConfirmar2h,
          ),
          _AlertRow(
            label: 'Perfiles pendientes de completar',
            value: perfilesPendientes,
          ),
          _AlertRow(label: 'Pagos vencidos', value: pagosVencidos),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isCritical = value > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCritical
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: 16,
            color: isCritical ? OcgColors.warning : OcgColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isCritical ? OcgColors.warning : OcgColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAgendaCard extends StatelessWidget {
  const _TodayAgendaCard({
    required this.ref,
    required this.loading,
    required this.hasError,
    required this.appointments,
  });

  final WidgetRef ref;
  final bool loading;
  final bool hasError;
  final List<AppointmentModel> appointments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agenda de hoy',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            const Text('No se pudo cargar la agenda del día.')
          else if (appointments.isEmpty)
            const Text('No hay citas programadas para hoy.')
          else
            ...appointments.map(
              (a) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OcgColors.mist,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: OcgColors.ivory,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _fmtHour(a.fechaHora),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.patientName.isEmpty
                                    ? 'Paciente sin nombre'
                                    : a.patientName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_tipoLabel(a.tipo)} • ${a.duracionMinutos} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: OcgColors.ink.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(status: a.estado),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (a.estado == AppointmentStatus.programada)
                          _ActionBtn(
                            tooltip: 'Confirmar',
                            icon: Icons.check_circle_outline,
                            color: OcgColors.success,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.confirmada,
                            ),
                          ),
                        if (a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Completar',
                            icon: Icons.task_alt,
                            color: OcgColors.success,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.completada,
                            ),
                          ),
                        if (a.estado == AppointmentStatus.programada ||
                            a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Reprogramar',
                            icon: Icons.edit_calendar_outlined,
                            color: OcgColors.bronze,
                            onTap: () => _showRescheduleDialog(context, a),
                          ),
                        if (a.estado == AppointmentStatus.programada ||
                            a.estado == AppointmentStatus.confirmada)
                          _ActionBtn(
                            tooltip: 'Cancelar',
                            icon: Icons.cancel_outlined,
                            color: OcgColors.error,
                            onTap: () => _updateStatus(
                              context,
                              a,
                              AppointmentStatus.cancelada,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppointmentModel appointment,
    AppointmentStatus status,
  ) async {
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appointment.id, status);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de cita actualizado.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    AppointmentModel appointment,
  ) async {
    final existingAppointments =
        ref.read(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    DateTime selected = appointment.fechaHora.add(const Duration(days: 1));

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        DateTime localSelected = selected;

        List<AppointmentTimeSlot> slotsForDay(DateTime day) {
          return AppointmentsBusinessRules.buildDailySlots(
            day: day,
            existingAppointments: existingAppointments,
            durationMinutes: appointment.duracionMinutos,
            excludeAppointmentId: appointment.id,
            stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
          );
        }

        return StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
            title: const Text('Reprogramar cita'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Nueva fecha: ${_fmtDateTime(localSelected)}'),
                    subtitle: const Text(
                      'Horario laboral L-V 08:00-12:00 / 14:00-18:00 · Sáb 08:00-12:00',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: localSelected,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );
                      if (d == null) return;
                      final firstAvailable = slotsForDay(
                        d,
                      ).where((s) => s.isAvailable).firstOrNull;
                      setDs(() {
                        localSelected =
                            firstAvailable?.start ??
                            DateTime(
                              d.year,
                              d.month,
                              d.day,
                              AppointmentsBusinessRules.workdayStartHour,
                              0,
                            );
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: slotsForDay(localSelected).map((slot) {
                      final label =
                          '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')}';
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color: slot.isAvailable
                                ? OcgColors.espresso
                                : Colors.grey.shade600,
                          ),
                        ),
                        selected:
                            slot.start == localSelected && slot.isAvailable,
                        disabledColor: Colors.grey.shade300,
                        selectedColor: OcgColors.sand,
                        onSelected: slot.isAvailable
                            ? (_) => setDs(() => localSelected = slot.start)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => popDialog(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OcgColors.bronze,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: () => popDialog(ctx, localSelected),
                child: const Text('Reprogramar'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    final workingHoursError =
        AppointmentsBusinessRules.validateWithinWorkingHours(
          start: result,
          durationMinutes: appointment.duracionMinutos,
        );
    if (workingHoursError != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(workingHoursError)));
      return;
    }

    final hasConflict = AppointmentsBusinessRules.hasTimeConflict(
      existingAppointments: existingAppointments,
      newStart: result,
      durationMinutes: appointment.duracionMinutos,
      excludeAppointmentId: appointment.id,
    );
    if (hasConflict) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ese horario está ocupado o dentro del buffer de 10 min.',
          ),
        ),
      );
      return;
    }

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .rescheduleAppointment(
            originalId: appointment.id,
            newAppointment: appointment.copyWith(
              id: '',
              fechaHora: result,
              estado: AppointmentStatus.programada,
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reprogramada exitosamente.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo reprogramar: $e')));
    }
  }

  static String _fmtDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${d.year} ${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }

  static String _tipoLabel(AppointmentType t) => switch (t) {
    AppointmentType.valoracion => 'Valoración',
    AppointmentType.control => 'Control',
    AppointmentType.instalacion => 'Instalación',
    AppointmentType.urgencia => 'Urgencia',
    AppointmentType.alta => 'Alta',
  };

  static String _fmtHour(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AppointmentStatus.programada => ('Programada', OcgColors.bronze),
      AppointmentStatus.confirmada => ('Confirmada', const Color(0xFF1565C0)),
      AppointmentStatus.completada => ('Completada', OcgColors.success),
      AppointmentStatus.cancelada => ('Cancelada', OcgColors.error),
      AppointmentStatus.noAsistio => ('No asistió', OcgColors.error),
      AppointmentStatus.reprogramada => ('Reprogramada', Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OcgColors.ivory,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: OcgColors.bronze, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OcgColors.espresso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.of(context).size.width > 800) return const SizedBox.shrink();

    final loading = ref.watch(authNotifierProvider).isLoading;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading
            ? null
            : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text(
                      '¿Deseas cerrar tu sesión de administrador?',
                    ),
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
                    const SnackBar(content: Text('No se pudo cerrar sesión.')),
                  );
                }
              },
        icon: const Icon(Icons.logout, color: OcgColors.error),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(color: OcgColors.error),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: OcgColors.error.withOpacity(0.08),
          side: BorderSide(color: OcgColors.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
