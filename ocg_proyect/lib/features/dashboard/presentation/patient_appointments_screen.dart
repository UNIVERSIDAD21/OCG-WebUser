import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

// ─── Helpers de formato ───────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtDateTime(DateTime d) =>
    '${_fmtDate(d)} a las '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

// ─── Filtro ───────────────────────────────────────────────────────────────────

enum _PatientFilter { proximas, historial }

// ─── PatientAppointmentsScreen ────────────────────────────────────────────────

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen> {
  _PatientFilter _filter = _PatientFilter.proximas;

  // ─── Diálogo nueva cita ──────────────────────────────────────────────────

  void _showNewAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    List<AppointmentModel> existingAppointments,
  ) {
    final cachedPatient = ref
        .read(patientByIdProvider(patientId))
        .asData
        ?.value;
    final nameFromAppts = existingAppointments
        .where((a) => a.patientName.isNotEmpty)
        .map((a) => a.patientName)
        .firstOrNull;
    final patientNombre = (cachedPatient?.nombre ?? nameFromAppts ?? '').trim();

    AppointmentType selectedType = AppointmentType.valoracion;
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      10,
      0,
    );
    final notesCtrl = TextEditingController();
    String? errorMsg;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Agendar nueva cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo (solo valoracion y control)
                DropdownButtonFormField<AppointmentType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cita',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: [AppointmentType.valoracion, AppointmentType.control]
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t == AppointmentType.valoracion
                                ? 'Valoración'
                                : 'Control',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedType = v ?? AppointmentType.valoracion;
                    errorMsg = null;
                  }),
                ),
                const SizedBox(height: 12),

                // Fecha y hora
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(_fmtDateTime(selectedDateTime)),
                  subtitle: const Text('Fecha y hora'),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now().add(const Duration(hours: 2)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (t == null) return;
                    setDialogState(() {
                      selectedDateTime = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                      errorMsg = null;
                    });
                  },
                ),

                // Notas opcionales
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),

                // Error
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: OcgColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.espresso,
                foregroundColor: OcgColors.ivory,
                minimumSize: const Size(100, 40),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      // Validar: no dos citas el mismo día
                      final sameDayError =
                          AppointmentsBusinessRules.validateNoSameDayAppointment(
                            existingAppointments: existingAppointments,
                            newAppointmentDateTime: selectedDateTime,
                          );
                      if (sameDayError != null) {
                        setDialogState(() => errorMsg = sameDayError);
                        return;
                      }

                      setDialogState(() => saving = true);

                      final finalNombre = patientNombre.isNotEmpty
                          ? patientNombre
                          : (ref
                                    .read(patientByIdProvider(patientId))
                                    .asData
                                    ?.value
                                    ?.nombre ??
                                patientId);

                      try {
                        await ref
                            .read(appointmentsRepositoryProvider)
                            .createAppointmentAsPatient(
                              AppointmentModel(
                                id: '',
                                patientId: patientId,
                                patientName: finalNombre,
                                tipo: selectedType,
                                estado: AppointmentStatus.programada,
                                fechaHora: selectedDateTime,
                                duracionMinutos: 30,
                                notas: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              ),
                            );

                        notesCtrl.dispose();
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Cita agendada exitosamente!'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (!dialogContext.mounted) return;

                        final msg = e.toString().contains('SLOT_TAKEN')
                            ? 'Este horario acaba de ser tomado. Elige otro.'
                            : 'No se pudo agendar. Verifica tu conexión.';

                        setDialogState(() => errorMsg = msg);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OcgColors.ivory,
                      ),
                    )
                  : const Text('Confirmar'),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!saving) notesCtrl.dispose();
    });
  }

  // ─── Filtrado ────────────────────────────────────────────────────────────

  List<AppointmentModel> _applyFilter(List<AppointmentModel> all) {
    final now = DateTime.now();
    switch (_filter) {
      case _PatientFilter.proximas:
        // Próximas: futuras, activas (programada o confirmada)
        return all
            .where(
              (a) =>
                  a.fechaHora.isAfter(now) &&
                  (a.estado == AppointmentStatus.programada ||
                      a.estado == AppointmentStatus.confirmada),
            )
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

      case _PatientFilter.historial:
        // ✅ Historial: pasadas + canceladas + reprogramadas
        // Incluye todos los estados históricos relevantes:
        //   completada, cancelada, noAsistio, reprogramada, y citas pasadas
        return all
            .where(
              (a) =>
                  !a.fechaHora.isAfter(now) ||
                  a.estado == AppointmentStatus.cancelada ||
                  a.estado == AppointmentStatus.reprogramada,
            )
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus citas.')),
      );
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        icon: const Icon(Icons.add),
        label: const Text('Agendar cita'),
        onPressed: () => _showNewAppointmentDialog(
          context,
          ref,
          user.uid,
          appointmentsAsync.asData?.value ?? const [],
        ),
      ),
      body: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [OcgColors.espresso, OcgColors.bronze],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis citas',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Próximas citas e historial de asistencia',
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Segmented button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SegmentedButton<_PatientFilter>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? OcgColors.espresso
                      : OcgColors.ivory,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? OcgColors.ivory
                      : OcgColors.ink,
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: OcgColors.bronze),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _PatientFilter.proximas,
                  label: Text('Próximas'),
                ),
                ButtonSegment(
                  value: _PatientFilter.historial,
                  label: Text('Historial'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),

          // ── Lista ──
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('No se pudo cargar citas: $e')),
              data: (all) {
                final filtered = _applyFilter(all);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filter == _PatientFilter.proximas
                              ? Icons.event_available_outlined
                              : Icons.history_outlined,
                          size: 52,
                          color: OcgColors.bronze.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == _PatientFilter.proximas
                              ? 'No tienes citas próximas.'
                              : 'No hay historial de citas.',
                          style: TextStyle(
                            color: OcgColors.ink.withOpacity(0.5),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PatientAppointmentCard(
                    appointment: filtered[index],
                    showCancelButton: _filter == _PatientFilter.proximas,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta de cita para el paciente ────────────────────────────────────────

class _PatientAppointmentCard extends ConsumerStatefulWidget {
  const _PatientAppointmentCard({
    required this.appointment,
    required this.showCancelButton,
  });

  final AppointmentModel appointment;
  final bool showCancelButton;

  @override
  ConsumerState<_PatientAppointmentCard> createState() =>
      _PatientAppointmentCardState();
}

class _PatientAppointmentCardState
    extends ConsumerState<_PatientAppointmentCard> {
  bool _cancelling = false;

  // ─── Color e ícono según estado ──────────────────────────────────────────

  Color _statusColor() {
    switch (widget.appointment.estado) {
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
    switch (widget.appointment.estado) {
      case AppointmentStatus.programada:
        return Icons.schedule_outlined;
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
    switch (widget.appointment.estado) {
      case AppointmentStatus.programada:
        return 'Programada';
      case AppointmentStatus.confirmada:
        return 'Confirmada';
      case AppointmentStatus.completada:
        return 'Completada';
      case AppointmentStatus.cancelada:
        return 'Cancelada';
      case AppointmentStatus.noAsistio:
        return 'No asististe';
      case AppointmentStatus.reprogramada:
        return 'Reprogramada';
    }
  }

  String _tipoLabel(AppointmentType tipo) {
    switch (tipo) {
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

  // ─── Cancelar cita ───────────────────────────────────────────────────────
  //
  // ✅ CAMBIO: Usa cancelAppointmentAsPatient en lugar de
  //    updateAppointmentStatus, que fallaba por permisos de Firestore.
  //    cancelAppointmentAsPatient solo escribe {estado, updatedAt},
  //    lo cual sí está permitido por las reglas actualizadas.

  Future<void> _onCancelPressed(BuildContext context) async {
    final appt = widget.appointment;
    final canCancel = AppointmentsBusinessRules.canCancelAppointment(
      appt.fechaHora,
    );

    // Menos de 24h → redirigir a WhatsApp
    if (!canCancel) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No es posible cancelar desde la app'),
          content: RichText(
            text: TextSpan(
              style: TextStyle(
                color: OcgColors.ink.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
              children: const [
                TextSpan(
                  text:
                      'Tu cita es en menos de 24 horas.\n\nPara cancelar contáctanos por WhatsApp al ',
                ),
                TextSpan(
                  text: '+57 300 000 0000',
                  style: TextStyle(
                    color: OcgColors.bronze,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.espresso,
                foregroundColor: OcgColors.ivory,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Confirmar cancelación
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Text(
          'Tu cita de ${_tipoLabel(appt.tipo)} del ${_fmtDate(appt.fechaHora)} '
          'será cancelada. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OcgColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _cancelling = true);
    try {
      // ✅ Usar cancelAppointmentAsPatient (solo escribe estado + updatedAt)
      await ref
          .read(appointmentsRepositoryProvider)
          .cancelAppointmentAsPatient(appt.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita cancelada correctamente.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cancelar la cita: $e'),
          backgroundColor: OcgColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final statusColor = _statusColor();
    final dt = appt.fechaHora;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateStr = _fmtDate(dt);

    // Puede cancelar si está en estado activo y la cita es futura
    final canShowCancel =
        widget.showCancelButton &&
        (appt.estado == AppointmentStatus.programada ||
            appt.estado == AppointmentStatus.confirmada) &&
        appt.fechaHora.isAfter(DateTime.now());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ──
            Row(
              children: [
                // Ícono de estado
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(), color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Fecha y hora
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: OcgColors.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
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

            // ── Tipo ──
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 14,
                  color: OcgColors.ink.withOpacity(0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  _tipoLabel(appt.tipo),
                  style: TextStyle(
                    fontSize: 13,
                    color: OcgColors.ink.withOpacity(0.7),
                  ),
                ),
                if (appt.duracionMinutos > 0) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: OcgColors.ink.withOpacity(0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${appt.duracionMinutos} min',
                    style: TextStyle(
                      fontSize: 13,
                      color: OcgColors.ink.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),

            // ── Notas ──
            if (appt.notas != null && appt.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 14,
                    color: OcgColors.ink.withOpacity(0.4),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.notas!,
                      style: TextStyle(
                        fontSize: 12,
                        color: OcgColors.ink.withOpacity(0.55),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ✅ Etiqueta especial para estados históricos importantes
            if (appt.estado == AppointmentStatus.cancelada ||
                appt.estado == AppointmentStatus.reprogramada ||
                appt.estado == AppointmentStatus.completada ||
                appt.estado == AppointmentStatus.confirmada) ...[
              const SizedBox(height: 8),
              _HistoryEventBadge(estado: appt.estado),
            ],

            // ── Botón cancelar ──
            if (canShowCancel) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OcgColors.error,
                    side: const BorderSide(color: OcgColors.error),
                  ),
                  onPressed: _cancelling
                      ? null
                      : () => _onCancelPressed(context),
                  icon: _cancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: OcgColors.error,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(_cancelling ? 'Cancelando...' : 'Cancelar cita'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Badge de evento histórico ────────────────────────────────────────────────
//
// ✅ NUEVO: Muestra una línea descriptiva para los eventos importantes
//    del historial: cancelada, reprogramada, confirmada, completada.

class _HistoryEventBadge extends StatelessWidget {
  const _HistoryEventBadge({required this.estado});

  final AppointmentStatus estado;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String message;

    switch (estado) {
      case AppointmentStatus.cancelada:
        icon = Icons.cancel_outlined;
        color = OcgColors.error;
        message = 'Esta cita fue cancelada';
        break;
      case AppointmentStatus.reprogramada:
        icon = Icons.update;
        color = const Color(0xFF6A1B9A);
        message = 'Esta cita fue reprogramada';
        break;
      case AppointmentStatus.confirmada:
        icon = Icons.check_circle_outline;
        color = const Color(0xFF2E7D32);
        message = 'Cita confirmada por la clínica';
        break;
      case AppointmentStatus.completada:
        icon = Icons.task_alt;
        color = const Color(0xFF1565C0);
        message = 'Cita completada exitosamente';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
