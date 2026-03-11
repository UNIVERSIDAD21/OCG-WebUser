import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

String _appointmentFmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _appointmentFmtDateTime(DateTime date) =>
    '${_appointmentFmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

// ─── Filtros ──────────────────────────────────────────────────────────────────
// ✅ NUEVO: se agregó `canceladas` al enum
enum _AgendaFilter { hoy, activas, completadas, perdidas, canceladas }

// ─── Helpers de lógica de negocio ─────────────────────────────────────────────

bool _esPerdida(AppointmentModel a) {
  if (a.estado == AppointmentStatus.noAsistio) return true;
  if (a.estado == AppointmentStatus.programada) {
    final limite = DateTime.now().subtract(const Duration(days: 1));
    return a.fechaHora.isBefore(limite);
  }
  return false;
}

// ─── AdminAppointmentsScreen ──────────────────────────────────────────────────

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  static Future<void> showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    DateTime? baseDate,
    PatientModel? preselectedPatient,
  }) async {
    final patientSearchCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    PatientModel? selectedPatient = preselectedPatient;
    if (preselectedPatient != null) {
      patientSearchCtrl.text = preselectedPatient.nombre;
    }

    AppointmentType type = AppointmentType.control;
    int durationMinutes = 30;
    final dateSeed = baseDate ?? DateTime.now();
    DateTime dateTime = DateTime(
      dateSeed.year,
      dateSeed.month,
      dateSeed.day,
      10,
      0,
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, dialogRef, _) {
            final patients =
                dialogRef.watch(patientsStreamProvider).asData?.value ?? [];

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final filteredPatients = patientSearchCtrl.text.isEmpty
                    ? patients
                    : patients
                          .where(
                            (p) => p.nombre.toLowerCase().contains(
                              patientSearchCtrl.text.toLowerCase(),
                            ),
                          )
                          .toList();

                return AlertDialog(
                  title: const Text('Nueva cita'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Paciente
                        TextFormField(
                          controller: patientSearchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paciente',
                            prefixIcon: Icon(Icons.person_search),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        if (patientSearchCtrl.text.isNotEmpty &&
                            selectedPatient == null)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredPatients.length,
                              itemBuilder: (_, i) {
                                final p = filteredPatients[i];
                                return ListTile(
                                  title: Text(p.nombre),
                                  subtitle: Text(p.email),
                                  onTap: () {
                                    setDialogState(() {
                                      selectedPatient = p;
                                      patientSearchCtrl.text = p.nombre;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 10),

                        // Tipo
                        DropdownButtonFormField<AppointmentType>(
                          value: type,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de cita',
                            prefixIcon: Icon(Icons.medical_services_outlined),
                          ),
                          items: AppointmentType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_labelTipo(t)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => type = v ?? type),
                        ),
                        const SizedBox(height: 10),

                        // Fecha y hora
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: Text(_appointmentFmtDateTime(dateTime)),
                          subtitle: const Text('Fecha y hora'),
                          trailing: const Icon(Icons.edit, size: 16),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d == null) return;
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(dateTime),
                            );
                            if (t == null) return;
                            setDialogState(
                              () => dateTime = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),

                        // Duración
                        DropdownButtonFormField<int>(
                          value: durationMinutes,
                          decoration: const InputDecoration(
                            labelText: 'Duración (minutos)',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          items: [15, 30, 45, 60, 90, 120]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => durationMinutes = v ?? 30),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notas (opcional)',
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OcgColors.bronze,
                        foregroundColor: OcgColors.ivory,
                      ),
                      onPressed: selectedPatient == null
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              try {
                                await ref
                                    .read(appointmentsRepositoryProvider)
                                    .createAppointment(
                                      AppointmentModel(
                                        id: '',
                                        patientId: selectedPatient!.id,
                                        patientName: selectedPatient!.nombre,
                                        tipo: type,
                                        estado: AppointmentStatus.programada,
                                        fechaHora: dateTime,
                                        duracionMinutos: durationMinutes,
                                        notas: notesCtrl.text.trim().isEmpty
                                            ? null
                                            : notesCtrl.text.trim(),
                                      ),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cita creada.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No se pudo crear la cita: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      child: const Text('Crear cita'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    patientSearchCtrl.dispose();
    notesCtrl.dispose();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

String _labelTipo(AppointmentType t) {
  switch (t) {
    case AppointmentType.valoracion:
      return 'Valoración';
    case AppointmentType.control:
      return 'Control';
    case AppointmentType.instalacion:
      return 'Instalación';
    case AppointmentType.urgencia:
      return 'Urgencia';
    case AppointmentType.alta:
      return 'Alta';
  }
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  _AgendaFilter _filter = _AgendaFilter.hoy;

  // ─── Diálogo reprogramar ─────────────────────────────────────────────────

  Future<void> _showRescheduleDialog(AppointmentModel appt) async {
    DateTime newDateTime = appt.fechaHora;
    int newDuration = appt.duracionMinutos;
    final notesCtrl = TextEditingController(text: appt.notas ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reprogramar cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_appointmentFmtDateTime(newDateTime)),
                  subtitle: const Text('Fecha y hora'),
                  trailing: const Icon(Icons.edit_calendar, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: newDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newDateTime),
                    );
                    if (t == null) return;
                    setDialogState(
                      () => newDateTime = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: newDuration,
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m, child: Text('$m min')),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => newDuration = v ?? 30),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.bronze,
                foregroundColor: OcgColors.ivory,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(appointmentsRepositoryProvider)
                      .rescheduleAppointment(
                        originalId: appt.id,
                        newAppointment: appt.copyWith(
                          id: '',
                          fechaHora: newDateTime,
                          duracionMinutos: newDuration,
                          notas: notesCtrl.text.trim(),
                          estado: AppointmentStatus.programada,
                        ),
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cita reprogramada.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo reprogramar: $e')),
                  );
                }
              },
              child: const Text('Reprogramar'),
            ),
          ],
        ),
      ),
    );
    notesCtrl.dispose();
  }

  // ─── Diálogo cancelar ────────────────────────────────────────────────────

  Future<void> _showCancelDialog(AppointmentModel appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Seguro que deseas cancelar la cita de ${appt.patientName}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, mantenerla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OcgColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, AppointmentStatus.cancelada);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cita cancelada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
    }
  }

  // ─── Acción "No completada" ──────────────────────────────────────────────

  Future<void> _onNoCompletada(AppointmentModel appt) async {
    final now = DateTime.now();
    final nuevoEstado = appt.fechaHora.isBefore(now)
        ? AppointmentStatus.noAsistio
        : AppointmentStatus.programada;
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, nuevoEstado);
      if (!mounted) return;
      final msg = nuevoEstado == AppointmentStatus.programada
          ? 'Cita devuelta a Activas.'
          : 'Cita movida a Perdidas (fecha ya pasó).';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  // ─── Filtrado ────────────────────────────────────────────────────────────

  List<AppointmentModel> _applyFilter(
    List<AppointmentModel> all,
    DateTime selectedDate,
  ) {
    switch (_filter) {
      case _AgendaFilter.hoy:
        return all.where((a) {
          final d = a.fechaHora;
          return d.year == selectedDate.year &&
              d.month == selectedDate.month &&
              d.day == selectedDate.day &&
              a.estado != AppointmentStatus.cancelada &&
              a.estado != AppointmentStatus.reprogramada;
        }).toList();

      case _AgendaFilter.activas:
        return all
            .where(
              (a) =>
                  (a.estado == AppointmentStatus.programada ||
                      a.estado == AppointmentStatus.confirmada) &&
                  !_esPerdida(a),
            )
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

      case _AgendaFilter.completadas:
        return all
            .where((a) => a.estado == AppointmentStatus.completada)
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      case _AgendaFilter.perdidas:
        return all.where(_esPerdida).toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      // ✅ NUEVO: filtro de canceladas
      case _AgendaFilter.canceladas:
        return all
            .where((a) => a.estado == AppointmentStatus.cancelada)
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    }
  }

  // ─── ListView por filtro ─────────────────────────────────────────────────

  Widget _buildList(List<AppointmentModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _filter == _AgendaFilter.perdidas
                  ? Icons.event_busy_outlined
                  : _filter == _AgendaFilter.canceladas
                  ? Icons.cancel_outlined
                  : Icons.event_note_outlined,
              size: 48,
              color: OcgColors.bronze.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay citas para este filtro.',
              style: TextStyle(color: OcgColors.ink.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final appt = items[index];
        final repo = ref.read(appointmentsRepositoryProvider);

        switch (_filter) {
          case _AgendaFilter.hoy:
          case _AgendaFilter.activas:
            return AppointmentCard(
              appointment: appt,
              onConfirmar: appt.estado == AppointmentStatus.programada
                  ? () async {
                      await repo.updateAppointmentStatus(
                        appt.id,
                        AppointmentStatus.confirmada,
                      );
                    }
                  : null,
              onCompletar: appt.estado == AppointmentStatus.confirmada
                  ? () async {
                      await repo.updateAppointmentStatus(
                        appt.id,
                        AppointmentStatus.completada,
                      );
                    }
                  : null,
              onReprogramar: () => _showRescheduleDialog(appt),
              onCancelar: () => _showCancelDialog(appt),
            );

          case _AgendaFilter.completadas:
            return AppointmentCard(
              appointment: appt,
              onNoCompletada: () => _onNoCompletada(appt),
            );

          case _AgendaFilter.perdidas:
            return AppointmentCard(appointment: appt);

          // ✅ NUEVO: canceladas — solo informativa, sin acciones
          case _AgendaFilter.canceladas:
            return AppointmentCard(appointment: appt);
        }
      },
    );
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda de citas')),
      body: Column(
        children: [
          // ── Selector de fecha (visible solo en filtro "Por fecha") ──
          if (_filter == _AgendaFilter.hoy)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [OcgColors.bronze, OcgColors.sand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: OcgColors.bronze.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: OcgColors.ivory),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AdminAppointmentsScreen._fmtDate(selectedDate),
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: OcgColors.ivory,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked == null) return;
                      ref
                          .read(selectedAppointmentsDateProvider.notifier)
                          .setDate(picked);
                    },
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Cambiar'),
                  ),
                ],
              ),
            ),

          // ── Segmented Button de filtros — ✅ 5 opciones con scroll ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<_AgendaFilter>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    if (_filter == _AgendaFilter.perdidas) {
                      return OcgColors.error;
                    }
                    if (_filter == _AgendaFilter.canceladas) {
                      return const Color(0xFF6D4C41); // brown
                    }
                    return OcgColors.espresso;
                  }
                  return OcgColors.ivory;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return OcgColors.ivory;
                  }
                  return OcgColors.ink;
                }),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: OcgColors.bronze),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _AgendaFilter.hoy,
                  label: Text('Por fecha'),
                ),
                ButtonSegment(
                  value: _AgendaFilter.activas,
                  label: Text('Activas'),
                ),
                ButtonSegment(
                  value: _AgendaFilter.completadas,
                  label: Text('Completadas'),
                ),
                ButtonSegment(
                  value: _AgendaFilter.perdidas,
                  label: Text('Perdidas'),
                ),
                // ✅ NUEVO segmento
                ButtonSegment(
                  value: _AgendaFilter.canceladas,
                  label: Text('Canceladas'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),

          // ── Lista principal ──
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('No se pudo cargar agenda: $error')),
              data: (appointments) {
                final filtered = _applyFilter(appointments, selectedDate);
                return _buildList(filtered);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: selectedDate,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
      ),
    );
  }
}

// ─── AppointmentCard ──────────────────────────────────────────────────────────

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onConfirmar,
    this.onCompletar,
    this.onReprogramar,
    this.onCancelar,
    this.onNoCompletada,
  });

  final AppointmentModel appointment;
  final Future<void> Function()? onConfirmar;
  final Future<void> Function()? onCompletar;
  final VoidCallback? onReprogramar;
  final VoidCallback? onCancelar;
  final Future<void> Function()? onNoCompletada;

  bool get _hasActions =>
      onConfirmar != null ||
      onCompletar != null ||
      onReprogramar != null ||
      onCancelar != null ||
      onNoCompletada != null;

  Color _statusColor() {
    switch (appointment.estado) {
      case AppointmentStatus.programada:
        return OcgColors.bronze;
      case AppointmentStatus.confirmada:
        return const Color(0xFF2E7D32);
      case AppointmentStatus.completada:
        return const Color(0xFF1565C0);
      case AppointmentStatus.cancelada:
        return OcgColors.error;
      case AppointmentStatus.noAsistio:
        return const Color(0xFF6D4C41);
      case AppointmentStatus.reprogramada:
        return const Color(0xFF6A1B9A);
    }
  }

  IconData _statusIcon() {
    switch (appointment.estado) {
      case AppointmentStatus.programada:
        return Icons.schedule;
      case AppointmentStatus.confirmada:
        return Icons.check_circle_outline;
      case AppointmentStatus.completada:
        return Icons.task_alt;
      case AppointmentStatus.cancelada:
        return Icons.cancel_outlined;
      case AppointmentStatus.noAsistio:
        return Icons.event_busy_outlined;
      case AppointmentStatus.reprogramada:
        return Icons.update;
    }
  }

  String _statusLabel() {
    switch (appointment.estado) {
      case AppointmentStatus.programada:
        return 'Programada';
      case AppointmentStatus.confirmada:
        return 'Confirmada';
      case AppointmentStatus.completada:
        return 'Completada';
      case AppointmentStatus.cancelada:
        return 'Cancelada';
      case AppointmentStatus.noAsistio:
        return 'No asistió';
      case AppointmentStatus.reprogramada:
        return 'Reprogramada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = appointment.fechaHora;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final statusColor = _statusColor();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(_statusIcon(), color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labelTipo(appointment.tipo),
                        style: TextStyle(
                          fontSize: 12,
                          color: OcgColors.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (appointment.notas != null && appointment.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                appointment.notas!,
                style: TextStyle(
                  fontSize: 12,
                  color: OcgColors.ink.withOpacity(0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_hasActions) ...[
              const Divider(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (onConfirmar != null)
                    _ActionChip(
                      label: 'Confirmar',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF2E7D32),
                      onTap: onConfirmar!,
                    ),
                  if (onCompletar != null)
                    _ActionChip(
                      label: 'Completar',
                      icon: Icons.task_alt,
                      color: const Color(0xFF1565C0),
                      onTap: onCompletar!,
                    ),
                  if (onReprogramar != null)
                    _ActionChip(
                      label: 'Reprogramar',
                      icon: Icons.update,
                      color: const Color(0xFF6A1B9A),
                      onTap: () async => onReprogramar!(),
                    ),
                  if (onCancelar != null)
                    _ActionChip(
                      label: 'Cancelar',
                      icon: Icons.cancel_outlined,
                      color: OcgColors.error,
                      onTap: () async => onCancelar!(),
                    ),
                  if (onNoCompletada != null)
                    _ActionChip(
                      label: 'No completada',
                      icon: Icons.undo,
                      color: OcgColors.bronze,
                      onTap: onNoCompletada!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Chip de acción ───────────────────────────────────────────────────────────

class _ActionChip extends StatefulWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: _loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.color,
              ),
            )
          : Icon(widget.icon, size: 14, color: widget.color),
      label: Text(
        widget.label,
        style: TextStyle(
          fontSize: 12,
          color: widget.color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: widget.color.withOpacity(0.08),
      side: BorderSide(color: widget.color.withOpacity(0.3)),
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await widget.onTap();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
    );
  }
}
