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
import '../../dashboard/presentation/admin_appointments_agenda_helpers.dart';
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
    final urgencyDate = urgency.createdAt;

    // Citas activas/confirmadas desde la fecha de la urgencia en adelante
    final candidates =
        appointments
            .where((a) {
              final s = a.estado;
              final isActive =
                  s == AppointmentStatus.programada ||
                  s == AppointmentStatus.confirmada;
              return isActive &&
                  _isOperationalNormalAppointment(a) &&
                  a.patientId != urgency.patientId &&
                  (a.fechaHora.isAtSameMomentAs(urgencyDate) ||
                      a.fechaHora.isAfter(urgencyDate));
            })
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay citas activas/confirmadas desde la fecha de esta urgencia.',
          ),
        ),
      );
      return;
    }

    AppointmentModel? selectedCandidate = candidates.first;
    DateTime newDateTime = selectedCandidate.fechaHora.add(
      const Duration(days: 7),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ReprogramarDialog(
          urgency: urgency,
          candidates: candidates,
          appointments: appointments,
          initialSelected: selectedCandidate,
          initialNewDateTime: newDateTime,
        );
      },
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

class _UrgencyCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            _UrgencyAppointmentInfo(
              urgency: urgency,
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

class _UrgencyAppointmentInfo extends ConsumerWidget {
  const _UrgencyAppointmentInfo({required this.urgency});

  final UrgencyRequestModel urgency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReprogramada = urgency.reprogramadaFromId?.isNotEmpty == true;
    final hasCita = urgency.appointmentId?.isNotEmpty == true;

    if (!isReprogramada && !hasCita) return const SizedBox.shrink();

    final repo = ref.read(appointmentsRepositoryProvider);

    if (isReprogramada) {
      return FutureBuilder<AppointmentModel?>(
        future: repo.getAppointmentById(urgency.reprogramadaFromId!),
        builder: (context, snapOriginal) {
          final originalAppt = snapOriginal.data;
          return FutureBuilder<AppointmentModel?>(
            future: urgency.appointmentId != null
                ? repo.getAppointmentById(urgency.appointmentId!)
                : Future.value(null),
            builder: (context, snapUrgency) {
              final urgencyAppt = snapUrgency.data;
              return Container(
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
                      pacienteDesplazado:
                          urgency.reprogramadaPacienteNombre ??
                          originalAppt?.patientName ??
                          'Paciente',
                      citaPacienteDesplazado:
                          urgency.reprogramadaHoraOriginal ??
                          originalAppt?.fechaHora,
                      citaUrgencia:
                          urgency.appointmentFechaHora ??
                          urgencyAppt?.fechaHora,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    return FutureBuilder<AppointmentModel?>(
      future: repo.getAppointmentById(urgency.appointmentId!),
      builder: (context, snap) {
        final appt = snap.data;
        final fechaHora = urgency.appointmentFechaHora ?? appt?.fechaHora;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F3EB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8D8C8)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_available,
                size: 14,
                color: OcgColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fechaHora != null
                      ? 'Cita creada: ${_fmtDate(fechaHora)}'
                      : 'Cita creada: ${urgency.appointmentId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class _ReprogramarDialog extends ConsumerStatefulWidget {
  const _ReprogramarDialog({
    required this.urgency,
    required this.candidates,
    required this.appointments,
    required this.initialSelected,
    required this.initialNewDateTime,
  });

  final UrgencyRequestModel urgency;
  final List<AppointmentModel> candidates;
  final List<AppointmentModel> appointments;
  final AppointmentModel initialSelected;
  final DateTime initialNewDateTime;

  @override
  ConsumerState<_ReprogramarDialog> createState() => _ReprogramarDialogState();
}

class _ReprogramarDialogState extends ConsumerState<_ReprogramarDialog> {
  late AppointmentModel _selected;
  late DateTime _newDateTime;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
    _newDateTime = widget.initialNewDateTime;
  }

  Future<void> _pickNewDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _newDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_newDateTime),
    );
    if (!mounted) return;
    setState(() {
      _newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _newDateTime.hour,
        time?.minute ?? _newDateTime.minute,
      );
      _errorText = null;
    });
  }

  Future<void> _confirm() async {
    final notPastError = AppointmentsBusinessRules.validateStartNotInPast(
      start: _newDateTime,
    );
    final workingHoursError =
        AppointmentsBusinessRules.validateWithinWorkingHours(
          start: _newDateTime,
          durationMinutes: _selected.duracionMinutos,
        );
    final conflict = AppointmentsBusinessRules.hasTimeConflict(
      existingAppointments: widget.appointments,
      newStart: _newDateTime,
      durationMinutes: _selected.duracionMinutos,
      excludeAppointmentId: _selected.id,
    );
    if (notPastError != null || workingHoursError != null || conflict) {
      setState(() {
        _errorText =
            notPastError ?? workingHoursError ?? 'El nuevo horario ya esta ocupado.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final adminId = ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
      await ref.read(urgencyRepositoryProvider).rescheduleAppointmentForUrgency(
            request: widget.urgency,
            originalAppointment: _selected,
            newDateTimeForOriginal: _newDateTime,
            adminId: adminId,
            adminNotes: 'Slot liberado desde ${_selected.id}.',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita reprogramada y urgencia agendada.'),
        ),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _errorText = 'No se pudo reprogramar: $e';
      });
    }
  }

  String _appointmentDateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(d.year, d.month, d.day);
    final diff = dateDay.difference(today).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${weekdays[d.weekday - 1]} ${d.day}/${d.month}';
  }

  Widget _buildAgendaCard(AppointmentModel a, bool isSelected) {
    final ui = appointmentStatusUi(a);
    final timeLabel =
        '${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: _saving ? null : () => setState(() => _selected = a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8EE) : OcgColors.ivory,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : ui.line.withOpacity(0.18),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF6366F1).withOpacity(0.14)
                  : OcgColors.espresso.withOpacity(0.04),
              blurRadius: isSelected ? 20 : 14,
              offset: Offset(0, isSelected ? 10 : 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ui.line.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: ui.line,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OcgColors.espresso,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$timeLabel · ${appointmentTypeLabel(a.tipo)} · ${a.duracionMinutos} min',
                        style: TextStyle(
                          color: OcgColors.ink.withOpacity(0.68),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ui.line.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ui.label,
                    style: TextStyle(
                      color: ui.line,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (a.treatmentNameSnapshot != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.local_hospital_outlined,
                    size: 13,
                    color: OcgColors.ink.withOpacity(0.45),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    a.treatmentNameSnapshot!,
                    style: TextStyle(
                      color: OcgColors.ink.withOpacity(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (isSelected) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Seleccionada para reprogramar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFEDE8DC),
        appBar: AppBar(
          backgroundColor: OcgColors.ivory,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: OcgColors.espresso),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reprogramar cita',
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Selecciona la cita a mover y el nuevo horario',
                style: TextStyle(
                  color: OcgColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Urgency context banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.urgency.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: OcgColors.espresso,
                          ),
                        ),
                        Text(
                          widget.urgency.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: OcgColors.ink.withOpacity(0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Section header: Cita a mover
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.event_busy_outlined, size: 18, color: OcgColors.ink.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Cita a mover (${widget.candidates.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: OcgColors.espresso,
                    ),
                  ),
                ],
              ),
            ),
            // Candidates list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.candidates.length,
                itemBuilder: (context, index) {
                  final a = widget.candidates[index];
                  final showDateHeader =
                      index == 0 ||
                      _appointmentDateLabel(a.fechaHora) !=
                          _appointmentDateLabel(widget.candidates[index - 1].fechaHora);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDateHeader) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: OcgColors.ink.withOpacity(0.5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _appointmentDateLabel(a.fechaHora),
                                style: TextStyle(
                                  color: OcgColors.ink.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildAgendaCard(a, _selected.id == a.id),
                    ],
                  );
                },
              ),
            ),
            // Error message
            if (_errorText != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OcgColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OcgColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: OcgColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          color: OcgColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Bottom bar: Nuevo horario + Confirm
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_repeat_outlined,
                        size: 18,
                        color: OcgColors.ink.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Nuevo horario:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: OcgColors.espresso,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickNewDateTime,
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: Text(
                          appointmentFmtDateTime(_newDateTime),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _saving ? null : _confirm,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Confirmar reprogramación',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
