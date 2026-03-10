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
  //
  // ⚠️ IMPORTANTE — Por qué este método es void (no Future<void>):
  //
  // No hacemos NINGÚN await antes de showDialog. La razón es que
  // patientByIdProvider es un StreamProvider. Si usamos .future sobre él
  // cuando no está siendo escuchado activamente, Riverpod puede descartar
  // la suscripción antes de que Firestore responda → el await se cuelga
  // indefinidamente, el context queda no-montado, el diálogo nunca aparece.
  //
  // En cambio leemos el nombre sincrónicamente desde la caché del provider
  // (ya vivo porque build() hace watch del mismo stream) y pasamos la lista
  // de citas directamente desde build() para la validación mismo-día.

  void _showNewAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    List<AppointmentModel> existingAppointments,
  ) {
    // Nombre del paciente — lectura SÍNCRONA, sin await
    final cachedPatient =
        ref.read(patientByIdProvider(patientId)).asData?.value;
    final nameFromAppts = existingAppointments
        .where((a) => a.patientName.isNotEmpty)
        .map((a) => a.patientName)
        .firstOrNull;
    final patientNombre =
        (cachedPatient?.nombre ?? nameFromAppts ?? '').trim();

    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    // Estado interno del diálogo
    AppointmentType selectedType = AppointmentType.valoracion;
    DateTime selectedDateTime =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    final notesCtrl = TextEditingController();
    bool saving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Agendar cita'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tipo de cita — TODOS los tipos del proyecto ──
                  DropdownButtonFormField<AppointmentType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de cita',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: AppointmentType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.name),
                            ))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setDialogState(
                              () => selectedType =
                                  v ?? AppointmentType.valoracion,
                            ),
                  ),
                  const SizedBox(height: 14),

                  // ── Selector de fecha y hora ──
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: selectedDateTime,
                                firstDate: tomorrow,
                                lastDate: DateTime(2035),
                              );
                              if (picked == null) return;
                              if (!dialogContext.mounted) return;

                              final pickedTime = await showTimePicker(
                                context: dialogContext,
                                initialTime:
                                    TimeOfDay.fromDateTime(selectedDateTime),
                              );
                              if (pickedTime == null) return;

                              setDialogState(() {
                                selectedDateTime = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: OcgColors.bronze.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: OcgColors.bronze, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha y hora',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: OcgColors.ink.withOpacity(0.5),
                                    ),
                                  ),
                                  Text(
                                    _fmtDateTime(selectedDateTime),
                                    style: const TextStyle(
                                      color: OcgColors.bronze,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar_outlined,
                                size: 16, color: OcgColors.bronze),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(
                      'Duración: 30 minutos',
                      style: TextStyle(
                        fontSize: 11,
                        color: OcgColors.ink.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Notas ──
                  TextFormField(
                    controller: notesCtrl,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      hintText: 'Indicaciones, preguntas...',
                    ),
                    maxLines: 2,
                    maxLength: 300,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogContext).pop(),
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
                        // ── Validar: no dos citas el mismo día ──
                        final sameDayError = AppointmentsBusinessRules
                            .validateNoSameDayAppointment(
                          existingAppointments: existingAppointments,
                          newAppointmentDateTime: selectedDateTime,
                        );
                        if (sameDayError != null) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(sameDayError),
                              backgroundColor: OcgColors.error,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);

                        // Nombre final con fallback al intento en caché
                        final finalNombre = patientNombre.isNotEmpty
                            ? patientNombre
                            : (ref
                                    .read(patientByIdProvider(patientId))
                                    .asData
                                    ?.value
                                    ?.nombre ??
                                patientId);

                        try {
                          // ⚠️ Usar createAppointmentAsPatient — no createAppointment.
                          // createAppointment hace una query global en la colección
                          // appointments que las Firestore rules bloquean para pacientes
                          // (solo pueden leer sus propias citas).
                          // createAppointmentAsPatient escribe directamente con el
                          // patientId del usuario autenticado, lo que sí está permitido.
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
                              : 'No se pudo agendar. Verifica tu conexión e intenta de nuevo.';

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: OcgColors.error,
                            ),
                          );
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
          );
        },
      ),
    ).then((_) => notesCtrl.dispose());
  }

  // ─── Filtrado ────────────────────────────────────────────────────────────

  List<AppointmentModel> _applyFilter(List<AppointmentModel> all) {
    final now = DateTime.now();
    switch (_filter) {
      case _PatientFilter.proximas:
        return all
            .where((a) =>
                a.fechaHora.isAfter(now) &&
                a.estado != AppointmentStatus.cancelada &&
                a.estado != AppointmentStatus.reprogramada)
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      case _PatientFilter.historial:
        return all
            .where((a) =>
                !a.fechaHora.isAfter(now) ||
                a.estado == AppointmentStatus.cancelada ||
                a.estado == AppointmentStatus.reprogramada)
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
        body: Center(
            child: Text('Debes iniciar sesión para ver tus citas.')),
      );
    }

    // watch mantiene el StreamProvider vivo → la caché estará disponible
    // en _showNewAppointmentDialog cuando se lea sincrónicamente.
    final appointmentsAsync =
        ref.watch(patientAppointmentsProvider(user.uid));

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
                backgroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected)
                        ? OcgColors.espresso
                        : OcgColors.ivory),
                foregroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected)
                        ? OcgColors.ivory
                        : OcgColors.ink),
                side: const WidgetStatePropertyAll(
                    BorderSide(color: OcgColors.bronze)),
              ),
              segments: const [
                ButtonSegment(
                    value: _PatientFilter.proximas,
                    label: Text('Próximas')),
                ButtonSegment(
                    value: _PatientFilter.historial,
                    label: Text('Historial')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) =>
                  setState(() => _filter = s.first),
            ),
          ),

          // ── Lista ──
          Expanded(
            child: appointmentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                              color: OcgColors.ink.withOpacity(0.4)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _AppointmentTile(appointment: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _AppointmentTile ─────────────────────────────────────────────────────────

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile({required this.appointment});
  final AppointmentModel appointment;

  bool get _canCancel =>
      appointment.estado == AppointmentStatus.programada ||
      appointment.estado == AppointmentStatus.confirmada;

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
        return 'No asististe';
      case AppointmentStatus.reprogramada:
        return 'Reprogramada';
    }
  }

  Future<void> _onCancelPressed(BuildContext context, WidgetRef ref) async {
    final canCancel =
        AppointmentsBusinessRules.canCancelAppointment(appointment.fechaHora);

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
                        'Tu cita es en menos de 24 horas.\n\nPara cancelar contáctanos por WhatsApp al '),
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
          'Tu cita de ${appointment.tipo.name} del ${_fmtDate(appointment.fechaHora)} '
          'será cancelada. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: OcgColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref
        .read(appointmentsRepositoryProvider)
        .updateAppointmentStatus(appointment.id, AppointmentStatus.cancelada);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cita cancelada correctamente.'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = appointment.fechaHora;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final color = _statusColor();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withOpacity(0.12),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.tipo.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(dt)} · ${appointment.duracionMinutos} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: OcgColors.ink.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (appointment.notas != null &&
                appointment.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes,
                      size: 13, color: OcgColors.ink.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment.notas!,
                      style: TextStyle(
                        fontSize: 12,
                        color: OcgColors.ink.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_canCancel) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Cancelar cita'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OcgColors.error,
                    side: BorderSide(
                        color: OcgColors.error.withOpacity(0.55)),
                    textStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _onCancelPressed(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}