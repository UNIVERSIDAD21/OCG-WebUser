import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/ocg_loading_state.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/presentation/admin_appointments_formatters.dart';
import '../../dashboard/presentation/admin_appointments_screen.dart';
import '../data/models/appointment_model.dart';
import '../data/models/urgency_model.dart';
import '../domain/appointments_business_rules.dart';
import '../providers/appointments_provider.dart';
import '../providers/urgency_provider.dart';

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(UrgencyStatus status) => switch (status) {
  UrgencyStatus.pendiente => const Color(0xFFEF4444),
  UrgencyStatus.enProceso => const Color(0xFFF59E0B),
  UrgencyStatus.atendida => const Color(0xFF10B981),
  UrgencyStatus.reprogramada => const Color(0xFF6366F1),
  UrgencyStatus.rechazada => const Color(0xFF6B7280),
};

bool _isOperationalNormalAppointment(AppointmentModel appointment) {
  final isOperational =
      appointment.estado == AppointmentStatus.programada ||
      appointment.estado == AppointmentStatus.confirmada;
  return isOperational && appointment.tipo != AppointmentType.urgencia;
}

class AdminUrgencyScreen extends ConsumerStatefulWidget {
  const AdminUrgencyScreen({super.key, this.embeddedInMobileShell = false});

  final bool embeddedInMobileShell;

  @override
  ConsumerState<AdminUrgencyScreen> createState() => _AdminUrgencyScreenState();
}

class _AdminUrgencyScreenState extends ConsumerState<AdminUrgencyScreen> {
  bool _showHistory = false;

  Future<void> _createAppointmentFromUrgency(
    BuildContext context,
    UrgencyRequestModel urgency,
    List<AppointmentModel> appointments,
  ) async {
    final fallbackPatient = ref
        .read(urgencyRepositoryProvider)
        .patientFromUrgency(urgency);
    if (!context.mounted) return;
    await AdminAppointmentsScreen.showCreateDialog(
      context,
      ref,
      preselectedPatient: fallbackPatient,
      existingAppointments: appointments,
      urgencyRequest: urgency,
    );
  }

  Future<void> _rejectUrgency(
    BuildContext context,
    UrgencyRequestModel urgency,
  ) async {
    final notesCtrl = TextEditingController(text: urgency.adminNotes ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar urgencia'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo o nota interna',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OcgColors.error),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    final notes = notesCtrl.text.trim();
    notesCtrl.dispose();
    if (confirmed != true) return;
    await ref
        .read(urgencyRepositoryProvider)
        .updateStatus(
          requestId: urgency.id,
          newStatus: UrgencyStatus.rechazada,
          adminNotes: notes,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Urgencia rechazada.')));
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    UrgencyRequestModel urgency,
    List<AppointmentModel> appointments,
  ) async {
    final now = DateTime.now();
    final candidates =
        appointments
            .where(_isOperationalNormalAppointment)
            .where((appointment) => appointment.patientId != urgency.patientId)
            .where((appointment) => appointment.fechaHora.isAfter(now))
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay citas normales futuras para reprogramar.'),
        ),
      );
      return;
    }

    AppointmentModel selected = candidates.first;
    DateTime newDateTime = selected.fechaHora.add(const Duration(days: 7));
    bool saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDateTime() async {
            final date = await showDatePicker(
              context: dialogContext,
              initialDate: newDateTime,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 120)),
            );
            if (date == null) return;
            if (!dialogContext.mounted) return;
            final time = await showTimePicker(
              context: dialogContext,
              initialTime: TimeOfDay.fromDateTime(newDateTime),
            );
            setDialogState(() {
              newDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time?.hour ?? newDateTime.hour,
                time?.minute ?? newDateTime.minute,
              );
              errorText = null;
            });
          }

          return AlertDialog(
            title: const Text('Reprogramar para dar slot'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UrgencySummary(urgency: urgency),
                    const SizedBox(height: 14),
                    const Text(
                      'Selecciona la cita que se movera:',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...candidates
                        .take(12)
                        .map(
                          (appointment) => RadioListTile<AppointmentModel>(
                            value: appointment,
                            groupValue: selected,
                            dense: true,
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setDialogState(() {
                                      selected = value;
                                      newDateTime = value.fechaHora.add(
                                        const Duration(days: 7),
                                      );
                                      errorText = null;
                                    });
                                  },
                            title: Text(
                              '${appointmentFmtDateTime(appointment.fechaHora)} - ${appointment.patientName}',
                            ),
                            subtitle: Text(
                              '${appointmentTypeLabel(appointment.tipo)} - ${appointment.patientPhone}',
                            ),
                          ),
                        ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: const Text('Nuevo horario de la cita movida'),
                      subtitle: Text(appointmentFmtDateTime(newDateTime)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: saving ? null : pickDateTime,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: OcgColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => popDialog(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final notPastError =
                            AppointmentsBusinessRules.validateStartNotInPast(
                              start: newDateTime,
                            );
                        final workingHoursError =
                            AppointmentsBusinessRules.validateWithinWorkingHours(
                              start: newDateTime,
                              durationMinutes: selected.duracionMinutos,
                            );
                        final conflict =
                            AppointmentsBusinessRules.hasTimeConflict(
                              existingAppointments: appointments,
                              newStart: newDateTime,
                              durationMinutes: selected.duracionMinutos,
                              excludeAppointmentId: selected.id,
                            );
                        if (notPastError != null ||
                            workingHoursError != null ||
                            conflict) {
                          setDialogState(() {
                            errorText =
                                notPastError ??
                                workingHoursError ??
                                'El nuevo horario ya esta ocupado.';
                          });
                          return;
                        }

                        setDialogState(() {
                          saving = true;
                          errorText = null;
                        });
                        try {
                          final adminId =
                              ref.read(authStateProvider).asData?.value?.uid ??
                              'admin';
                          await ref
                              .read(urgencyRepositoryProvider)
                              .rescheduleAppointmentForUrgency(
                                request: urgency,
                                originalAppointment: selected,
                                newDateTimeForOriginal: newDateTime,
                                adminId: adminId,
                                adminNotes:
                                    'Slot liberado desde ${selected.id}.',
                              );
                          if (dialogContext.mounted) popDialog(dialogContext);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cita reprogramada y urgencia agendada.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                            errorText = 'No se pudo reprogramar: $e';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar cambio'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgenciesAsync = ref.watch(allUrgenciesProvider);
    final appointments =
        ref.watch(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    final pendingCount =
        ref.watch(pendingUrgenciesCountProvider).asData?.value ?? 0;

    final content = _UrgenciesContent(
      urgenciesAsync: urgenciesAsync,
      appointments: appointments,
      pendingCount: pendingCount,
      showHistory: _showHistory,
      onToggleHistory: () => setState(() => _showHistory = !_showHistory),
      onCreateAppointment: (urgency) =>
          _createAppointmentFromUrgency(context, urgency, appointments),
      onReschedule: (urgency) =>
          _showRescheduleDialog(context, urgency, appointments),
      onReject: (urgency) => _rejectUrgency(context, urgency),
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(
        title: 'Urgencias',
        scrollable: false,
        child: content,
      );
    }

    if (widget.embeddedInMobileShell) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: SafeArea(child: content),
    );
  }
}

class _UrgenciesContent extends StatelessWidget {
  const _UrgenciesContent({
    required this.urgenciesAsync,
    required this.appointments,
    required this.pendingCount,
    required this.showHistory,
    required this.onToggleHistory,
    required this.onCreateAppointment,
    required this.onReschedule,
    required this.onReject,
  });

  final AsyncValue<List<UrgencyRequestModel>> urgenciesAsync;
  final List<AppointmentModel> appointments;
  final int pendingCount;
  final bool showHistory;
  final VoidCallback onToggleHistory;
  final ValueChanged<UrgencyRequestModel> onCreateAppointment;
  final ValueChanged<UrgencyRequestModel> onReschedule;
  final ValueChanged<UrgencyRequestModel> onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UrgencyHeader(pendingCount: pendingCount),
        const SizedBox(height: 12),
        Expanded(
          child: urgenciesAsync.when(
            loading: () => const Center(child: OcgLoadingState()),
            error: (e, _) => Center(
              child: OcgEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'No se pudieron cargar las urgencias',
                subtitle: '$e',
              ),
            ),
            data: (urgencies) {
              final active = urgencies.where((u) => u.isActive).toList();
              final history = urgencies.where((u) => !u.isActive).toList();

              if (urgencies.isEmpty) {
                return const Center(
                  child: OcgEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Sin solicitudes de urgencia',
                    subtitle: 'No hay urgencias registradas',
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: OcgEmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Sin urgencias activas',
                        subtitle:
                            'Las solicitudes resueltas quedan en historial.',
                      ),
                    )
                  else
                    ...active.map(
                      (urgency) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _UrgencyCard(
                          urgency: urgency,
                          onCreateAppointment: () =>
                              onCreateAppointment(urgency),
                          onReschedule: () => onReschedule(urgency),
                          onReject: () => onReject(urgency),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onToggleHistory,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: OcgColors.espresso),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Historial (${history.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: OcgColors.espresso,
                              ),
                            ),
                          ),
                          Icon(
                            showHistory ? Icons.expand_less : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showHistory)
                    ...history.map(
                      (urgency) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _UrgencyCard(
                          urgency: urgency,
                          compact: true,
                          onCreateAppointment: () =>
                              onCreateAppointment(urgency),
                          onReschedule: () => onReschedule(urgency),
                          onReject: () => onReject(urgency),
                        ),
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
}

class _UrgencyHeader extends StatelessWidget {
  const _UrgencyHeader({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2016), Color(0xFF4A3628), Color(0xFF2C2016)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitudes de urgencia',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Administra casos prioritarios y slots liberados',
                  style: TextStyle(color: OcgColors.ivory, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$pendingCount pendientes',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencySummary extends StatelessWidget {
  const _UrgencySummary({required this.urgency});

  final UrgencyRequestModel urgency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE4E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            urgency.patientName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(urgency.descripcion),
        ],
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({
    required this.urgency,
    required this.onCreateAppointment,
    required this.onReschedule,
    required this.onReject,
    this.compact = false,
  });

  final UrgencyRequestModel urgency;
  final VoidCallback onCreateAppointment;
  final VoidCallback onReschedule;
  final VoidCallback onReject;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(urgency.estado);
    final canAct = urgency.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canAct ? statusColor.withOpacity(0.34) : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  urgency.estadoLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _fmtDate(urgency.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${urgency.patientName} - ${urgency.patientPhone}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            urgency.descripcion,
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: OcgColors.ink.withOpacity(0.78)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: OcgColors.ink.withOpacity(0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Paciente ya redirigido a WhatsApp',
                  style: TextStyle(
                    color: OcgColors.ink.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (urgency.appointmentId?.isNotEmpty == true ||
              urgency.reprogramadaFromId?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F3EB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8D8C8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urgency.appointmentId?.isNotEmpty == true &&
                      urgency.reprogramadaFromId?.isEmpty != false) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available,
                          size: 14,
                          color: OcgColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cita creada: ${urgency.appointmentFechaHora != null ? _fmtDate(urgency.appointmentFechaHora!) : urgency.appointmentId}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OcgColors.espresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (urgency.reprogramadaFromId?.isNotEmpty == true) ...[
                    const Text(
                      'Reprogramación de cita',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ReprogramacionDetail(
                      pacienteDesplazado: urgency.reprogramadaPacienteNombre ?? 'Paciente',
                      citaPacienteDesplazado: urgency.reprogramadaHoraOriginal,
                      citaUrgencia: urgency.appointmentFechaHora,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (canAct && !compact) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateAppointment,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Crear cita'),
                ),
                OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Reprogramar'),
                ),
                TextButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReprogramacionDetail extends StatelessWidget {
  const _ReprogramacionDetail({
    required this.pacienteDesplazado,
    required this.citaPacienteDesplazado,
    required this.citaUrgencia,
  });

  final String pacienteDesplazado;
  final DateTime? citaPacienteDesplazado;
  final DateTime? citaUrgencia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, size: 14, color: Color(0xFF6E5644)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Paciente desplazado: $pacienteDesplazado',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: OcgColors.espresso,
                ),
              ),
            ),
          ],
        ),
        if (citaPacienteDesplazado != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFFB06A5A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cita paciente desplazado: ${_fmtDate(citaPacienteDesplazado!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E5644),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (citaUrgencia != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cita urgencia: ${_fmtDate(citaUrgencia!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E5644),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
