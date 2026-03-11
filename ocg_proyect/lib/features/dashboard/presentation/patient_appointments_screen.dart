import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtDateTime(DateTime d) =>
    '${_fmtDate(d)} a las '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _tipoLabel(AppointmentType t) => switch (t) {
  AppointmentType.valoracion => 'Valoración',
  AppointmentType.control => 'Control',
  AppointmentType.instalacion => 'Instalación',
  AppointmentType.urgencia => 'Urgencia',
  AppointmentType.alta => 'Alta',
};

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

    // ✅ Teléfono del paciente para el campo creadoPor + patientPhone
    final patientPhone = cachedPatient?.telefono ?? '';

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
        builder: (dialogContext, setDs) => AlertDialog(
          title: const Text('Agendar nueva cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          child: Text(_tipoLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDs(() {
                    selectedType = v ?? AppointmentType.valoracion;
                    errorMsg = null;
                  }),
                ),
                const SizedBox(height: 12),
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
                    setDs(() {
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
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
                      final sameDayError =
                          AppointmentsBusinessRules.validateNoSameDayAppointment(
                            existingAppointments: existingAppointments,
                            newAppointmentDateTime: selectedDateTime,
                          );
                      if (sameDayError != null) {
                        setDs(() => errorMsg = sameDayError);
                        return;
                      }

                      setDs(() => saving = true);

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
                                // ✅ campos nuevos
                                patientPhone: patientPhone,
                                creadoPor: patientId,
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
                        setDs(() => saving = false);
                        if (!dialogContext.mounted) return;
                        final msg = e.toString().contains('SLOT_TAKEN')
                            ? 'Este horario acaba de ser tomado. Elige otro.'
                            : 'No se pudo agendar. Verifica tu conexión.';
                        setDs(() => errorMsg = msg);
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
        // ✅ Historial: todo lo que ya pasó + canceladas + reprogramadas
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
                  'Próximas citas e historial',
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
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
                  itemBuilder: (ctx, i) => _PatientAppointmentCard(
                    appointment: filtered[i],
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

  Color _statusColor() => switch (widget.appointment.estado) {
    AppointmentStatus.programada => OcgColors.bronze,
    AppointmentStatus.confirmada => const Color(0xFF2E7D32),
    AppointmentStatus.completada => const Color(0xFF1565C0),
    AppointmentStatus.cancelada => OcgColors.error,
    AppointmentStatus.noAsistio => const Color(0xFF6D4C41),
    AppointmentStatus.reprogramada => const Color(0xFF6A1B9A),
  };

  IconData _statusIcon() => switch (widget.appointment.estado) {
    AppointmentStatus.programada => Icons.schedule_outlined,
    AppointmentStatus.confirmada => Icons.check_circle_outline,
    AppointmentStatus.completada => Icons.task_alt,
    AppointmentStatus.cancelada => Icons.cancel_outlined,
    AppointmentStatus.noAsistio => Icons.event_busy_outlined,
    AppointmentStatus.reprogramada => Icons.update,
  };

  String _statusLabel() => switch (widget.appointment.estado) {
    AppointmentStatus.programada => 'Programada',
    AppointmentStatus.confirmada => 'Confirmada',
    AppointmentStatus.completada => 'Completada',
    AppointmentStatus.cancelada => 'Cancelada',
    AppointmentStatus.noAsistio => 'No asististe',
    AppointmentStatus.reprogramada => 'Reprogramada',
  };

  // ─── Cancelar ────────────────────────────────────────────────────────────
  //
  // ✅ Usa cancelAppointmentAsPatient — solo escribe {estado, updatedAt}
  //    lo cual sí permite la regla Firestore actualizada.

  Future<void> _onCancelPressed(BuildContext context) async {
    final appt = widget.appointment;
    final canCancel = AppointmentsBusinessRules.canCancelAppointment(
      appt.fechaHora,
    );

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
                      'Tu cita es en menos de 24 horas.\n\nPara cancelar llámanos al WhatsApp ',
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
          content: Text('No se pudo cancelar: $e'),
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
    final sc = _statusColor();
    final dt = appt.fechaHora;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final canShowCancel =
        widget.showCancelButton &&
        (appt.estado == AppointmentStatus.programada ||
            appt.estado == AppointmentStatus.confirmada) &&
        appt.fechaHora.isAfter(DateTime.now());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(), color: sc, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtDate(dt),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sc.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sc,
                    ),
                  ),
                ),
              ],
            ),
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
            ),
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

            // ✅ Badge de evento histórico
            if (appt.estado == AppointmentStatus.cancelada ||
                appt.estado == AppointmentStatus.reprogramada ||
                appt.estado == AppointmentStatus.completada ||
                appt.estado == AppointmentStatus.confirmada) ...[
              const SizedBox(height: 8),
              _HistoryEventBadge(estado: appt.estado),
            ],

            // ─── Botón cancelar ──────────────────────────────────────────
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
// ✅ Muestra un indicador descriptivo para los estados relevantes:
//    cancelada, reprogramada, confirmada, completada.

class _HistoryEventBadge extends StatelessWidget {
  const _HistoryEventBadge({required this.estado});
  final AppointmentStatus estado;

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = switch (estado) {
      AppointmentStatus.cancelada => (
        Icons.cancel_outlined,
        OcgColors.error,
        'Esta cita fue cancelada',
      ),
      AppointmentStatus.reprogramada => (
        Icons.update,
        const Color(0xFF6A1B9A),
        'Esta cita fue reprogramada',
      ),
      AppointmentStatus.confirmada => (
        Icons.check_circle_outline,
        const Color(0xFF2E7D32),
        'Cita confirmada por la clínica',
      ),
      AppointmentStatus.completada => (
        Icons.task_alt,
        const Color(0xFF1565C0),
        'Cita completada exitosamente',
      ),
      _ => (Icons.info_outline, OcgColors.bronze, ''),
    };

    if (message.isEmpty) return const SizedBox.shrink();

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
