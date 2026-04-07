import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/providers/availability_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/constants/contact_channels.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/whatsapp_support.dart';
import '../../patients/presentation/patient_viewer_mode.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtDateTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${_fmtDate(d)} a las '
      '${hour12.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')} $suffix';
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _tipoLabel(AppointmentType t) => switch (t) {
  AppointmentType.valoracion => 'Valoración',
  AppointmentType.control => 'Control',
  AppointmentType.instalacion => 'Instalación',
  AppointmentType.urgencia => 'Urgencia',
  AppointmentType.alta => 'Alta',
};

String _estadoLabel(AppointmentStatus s) => switch (s) {
  AppointmentStatus.programada => 'Programada',
  AppointmentStatus.confirmada => 'Confirmada',
  AppointmentStatus.completada => 'Completada',
  AppointmentStatus.cancelada => 'Cancelada',
  AppointmentStatus.noAsistio => 'No asistió',
  AppointmentStatus.reprogramada => 'Reprogramada',
};

Color _estadoColor(AppointmentStatus s) => switch (s) {
  AppointmentStatus.programada => OcgColors.bronze,
  AppointmentStatus.confirmada => const Color(0xFF1565C0),
  AppointmentStatus.completada => const Color(0xFF2E7D32),
  AppointmentStatus.cancelada => OcgColors.error,
  AppointmentStatus.noAsistio => OcgColors.error,
  AppointmentStatus.reprogramada => Colors.purple,
};

enum _PatientFilter { proximas, historial }

// ─── PatientAppointmentsScreen ────────────────────────────────────────────────

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
    this.viewerMode = PatientViewerMode.patient,
  });

  final bool embedded;
  final String? patientIdOverride;
  final PatientViewerMode viewerMode;

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen> {
  _PatientFilter _filter = _PatientFilter.proximas;

  Future<void> _handleSignOut() async {
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
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
    }
  }

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
    final authDisplayName =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
    final patientNombre =
        (cachedPatient?.nombre.isNotEmpty == true
                ? cachedPatient!.nombre
                : nameFromAppts?.isNotEmpty == true
                ? nameFromAppts!
                : authDisplayName)
            .trim();
    final patientPhone = cachedPatient?.telefono ?? '';

    String notesText = '';
    bool expandMorning = true;
    bool expandAfternoon = true;

    AppointmentType selectedType = AppointmentType.valoracion;
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      AppointmentsBusinessRules.workdayStartHour,
      0,
    );
    String? errorMsg;
    bool saving = false;

    DateTime dateFromLabel(DateTime baseDay, String label) {
      final normalized = label.trim().toUpperCase();
      final hasAmPm = normalized.endsWith('AM') || normalized.endsWith('PM');

      final timePart = hasAmPm
          ? normalized.substring(0, normalized.length - 2).trim()
          : normalized;
      final parts = timePart.split(':');
      var hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (hasAmPm) {
        final isPm = normalized.endsWith('PM');
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      }

      return DateTime(baseDay.year, baseDay.month, baseDay.day, hour, minute);
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDs) => AlertDialog(
          title: const Text('Agendar nueva cita'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AppointmentType>(
                    initialValue: selectedType,
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
                    onChanged: (v) => setDs(
                      () => selectedType = v ?? AppointmentType.valoracion,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.schedule,
                      color: OcgColors.espresso,
                    ),
                    title: const Text('Fecha'),
                    subtitle: Text(
                      _fmtDateTime(selectedDateTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OcgColors.espresso,
                      ),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDateTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (pickedDate == null) return;
                      setDs(() {
                        selectedDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          AppointmentsBusinessRules.workdayStartHour,
                          0,
                        );
                        errorMsg = null;
                      });
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecciona un horario por jornada. Mañana arriba y tarde abajo. Puedes desplegar o recoger cada bloque.',
                      style: TextStyle(
                        fontSize: 12,
                        color: OcgColors.ink.withOpacity(0.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder(
                    stream: ref
                        .read(availabilityRepositoryProvider)
                        .watchAvailabilityByDay(_dayKey(selectedDateTime)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final availability = snapshot.data;
                      final orderedSlots = AppointmentsBusinessRules.buildAllWorkdaySlots(
                        day: selectedDateTime,
                        stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
                      ).toList()
                        ..sort((a, b) => a.start.compareTo(b.start));
                      final allLabels = orderedSlots.map((s) => s.label).toList();

                      const operationalMinutes =
                          30 + AppointmentsBusinessRules.bufferMinutesBetweenAppointments;

                      bool isStartAvailable(String label) {
                        if (snapshot.hasError) return false;

                        final start = dateFromLabel(selectedDateTime, label);
                        final notPastError = AppointmentsBusinessRules.validateStartNotInPast(
                          start: start,
                        );
                        if (notPastError != null) return false;

                        final fitsWorkingHours = AppointmentsBusinessRules.validateWithinWorkingHours(
                              start: start,
                              durationMinutes: operationalMinutes,
                            ) ==
                            null;
                        if (!fitsWorkingHours) return false;

                        if (availability == null) return true;

                        final end = start.add(const Duration(minutes: operationalMinutes));
                        for (final slotLabel in allLabels) {
                          final slotStart = dateFromLabel(selectedDateTime, slotLabel);
                          final slotEnd = slotStart.add(
                            Duration(minutes: AppointmentsBusinessRules.slotStepMinutes),
                          );
                          final overlaps = slotStart.isBefore(end) && start.isBefore(slotEnd);
                          if (overlaps && availability.slots[slotLabel] == false) {
                            return false;
                          }
                        }

                        return true;
                      }

                      final availableLabels = allLabels.where(isStartAvailable).toList();

                      if (availableLabels.isEmpty) {
                        return const Text(
                          'No hay horarios disponibles para ese día.',
                          style: TextStyle(color: OcgColors.error),
                        );
                      }

                      final morningLabels = availableLabels
                          .where((label) {
                            final d = dateFromLabel(selectedDateTime, label);
                            return d.hour < 12;
                          })
                          .toList();
                      final afternoonLabels = availableLabels
                          .where((label) {
                            final d = dateFromLabel(selectedDateTime, label);
                            return d.hour >= 12;
                          })
                          .toList();

                      Widget buildSlotChip(String label) {
                        final slotDate = dateFromLabel(selectedDateTime, label);
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: const TextStyle(color: OcgColors.espresso),
                          ),
                          selected: slotDate == selectedDateTime,
                          selectedColor: OcgColors.sand,
                          onSelected: (_) => setDs(() {
                            selectedDateTime = slotDate;
                            errorMsg = null;
                          }),
                        );
                      }

                      Widget buildPeriodSection({
                        required String title,
                        required bool expanded,
                        required VoidCallback onToggle,
                        required List<String> labels,
                      }) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7EF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: OcgColors.bronze.withOpacity(0.22)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: onToggle,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: OcgColors.espresso,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      expanded ? Icons.expand_less : Icons.expand_more,
                                      color: OcgColors.bronze,
                                    ),
                                  ],
                                ),
                              ),
                              if (expanded) ...[
                                const SizedBox(height: 8),
                                if (labels.isEmpty)
                                  Text(
                                    'Sin horarios en esta jornada.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: OcgColors.ink.withOpacity(0.6),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: labels.map(buildSlotChip).toList(),
                                  ),
                              ],
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.hasError)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'No se pudo consultar disponibilidad de la clínica. Intenta nuevamente.',
                                style: TextStyle(
                                  color: OcgColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          buildPeriodSection(
                            title: 'Mañana',
                            expanded: expandMorning,
                            onToggle: () => setDs(() => expandMorning = !expandMorning),
                            labels: morningLabels,
                          ),
                          buildPeriodSection(
                            title: 'Tarde',
                            expanded: expandAfternoon,
                            onToggle: () => setDs(() => expandAfternoon = !expandAfternoon),
                            labels: afternoonLabels,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: notesText,
                    onChanged: (v) => notesText = v,
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
          ),
          //
          actions: [
            TextButton(
              onPressed: saving ? null : () => popDialog(dialogContext),
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

                      final notPastError = AppointmentsBusinessRules.validateStartNotInPast(
                        start: selectedDateTime,
                      );
                      if (notPastError != null) {
                        setDs(() => errorMsg = notPastError);
                        return;
                      }

                      final workingHoursError =
                          AppointmentsBusinessRules.validateWithinWorkingHours(
                            start: selectedDateTime,
                            durationMinutes: 30,
                          );
                      if (workingHoursError != null) {
                        setDs(() => errorMsg = workingHoursError);
                        return;
                      }

                      try {
                        final availability = await ref
                            .read(availabilityRepositoryProvider)
                            .getAvailabilityByDay(_dayKey(selectedDateTime));

                        if (availability != null) {
                          const operationalMinutes =
                              30 + AppointmentsBusinessRules.bufferMinutesBetweenAppointments;
                          final end = selectedDateTime.add(
                            const Duration(minutes: operationalMinutes),
                          );

                          final allLabels = AppointmentsBusinessRules.buildAllWorkdaySlots(
                            day: selectedDateTime,
                            stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
                          ).map((s) => s.label);

                          bool stillAvailable = true;
                          for (final label in allLabels) {
                            final slotStart = dateFromLabel(selectedDateTime, label);
                            final slotEnd = slotStart.add(
                              Duration(minutes: AppointmentsBusinessRules.slotStepMinutes),
                            );
                            final overlaps = slotStart.isBefore(end) && selectedDateTime.isBefore(slotEnd);
                            if (overlaps && availability.slots[label] == false) {
                              stillAvailable = false;
                              break;
                            }
                          }

                          if (!stillAvailable) {
                            setDs(
                              () => errorMsg =
                                  'Ese horario ya no está disponible. Selecciona otro.',
                            );
                            return;
                          }
                        }
                      } catch (_) {
                        // Si falla lectura de disponibilidad, dejamos que backend
                        // haga validación final y devuelva error consistente.
                      }

                      setDs(() => saving = true);

                      final resolvedFromProvider = ref
                          .read(patientByIdProvider(patientId))
                          .asData
                          ?.value
                          ?.nombre;
                      final finalNombre = patientNombre.isNotEmpty
                          ? patientNombre
                          : resolvedFromProvider?.isNotEmpty == true
                          ? resolvedFromProvider!
                          : authDisplayName;

                      final notasTexto = notesText.trim();

                      try {
                        await ref
                            .read(appointmentsRepositoryProvider)
                            .createAppointmentAsPatient(
                              AppointmentModel(
                                id: '',
                                patientId: patientId,
                                patientName: finalNombre,
                                patientPhone: patientPhone,
                                creadoPor: patientId,
                                tipo: selectedType,
                                estado: AppointmentStatus.programada,
                                fechaHora: selectedDateTime,
                                duracionMinutos: 30,
                                notas: notasTexto.isEmpty ? null : notasTexto,
                              ),
                            );

                        // ✅ Cerrar con popDialog (safe en Flutter Web).
                        //    NO llamar notesCtrl.dispose() aquí — se hace
                        //    en el .then() de showDialog después de que
                        //    el widget se desmonta completamente.
                        popDialog(dialogContext);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Cita agendada exitosamente!'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      } catch (e) {
                        setDs(() {
                          saving = false;
                          errorMsg = e.toString().contains('SLOT_TAKEN')
                              ? 'Ese horario ya está ocupado. Elige otro.'
                              : 'No se pudo agendar. Intenta de nuevo.';
                        });
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
                  : const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Cancelar cita (con regla de 24 horas) ───────────────────────────────

  void _handleCancelTap(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
  ) {
    final horasHastaCita = appt.fechaHora.difference(DateTime.now()).inHours;

    if (horasHastaCita < 24) {
      // Menos de 24h → mostrar instrucción de WhatsApp
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelación con menos de 24 horas'),
          content: const Text(
            'Para cancelar tu cita con menos de 24 horas de anticipación, '
            'comunícate directamente con la clínica por WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => popDialog(ctx),
              child: const Text('Entendido'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                popDialog(ctx);

                final clinicPhone = ContactChannels.clinicWhatsapp;
                if (clinicPhone.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No hay número de WhatsApp configurado para la clínica.',
                      ),
                    ),
                  );
                  return;
                }

                final opened = await WhatsAppSupport.openChat(
                  phoneDigits: clinicPhone,
                  message:
                      'Hola, necesito cancelar/reprogramar mi cita del ${_fmtDateTime(appt.fechaHora)}. '
                      'Paciente: ${appt.patientName.isEmpty ? 'No registrado' : appt.patientName}.',
                );

                if (opened) return;
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No se pudo abrir WhatsApp automáticamente. '
                      'Por favor contacta a la clínica desde tu app o navegador.',
                    ),
                  ),
                );
              },
              child: const Text('Abrir WhatsApp'),
            ),
          ],
        ),
      );
      return;
    }

    // ≥ 24h → confirmar cancelación normal
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Text(
          'Cita del ${_fmtDateTime(appt.fechaHora)}.\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx),
            child: const Text('No, mantenerla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () async {
              popDialog(ctx); // ✅ cerrar primero
              try {
                await ref
                    .read(appointmentsRepositoryProvider)
                    .updateAppointmentStatus(
                      appt.id,
                      AppointmentStatus.cancelada,
                    );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cita cancelada.'),
                    backgroundColor: OcgColors.error,
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
              }
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final isAdminViewer = widget.viewerMode == PatientViewerMode.adminViewer;
    final effectivePatientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');

    if (effectivePatientId.isEmpty) {
      return const Center(child: Text('Debes iniciar sesión.'));
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(effectivePatientId));

    final proximasCount = appointmentsAsync.asData?.value
            ?.where(
              (a) =>
                  a.fechaHora.isAfter(DateTime.now()) &&
                  a.estado != AppointmentStatus.cancelada &&
                  a.estado != AppointmentStatus.noAsistio &&
                  a.estado != AppointmentStatus.completada,
            )
            .length ??
        0;

    final content = Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFF8F5F0),
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 22,
            20,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdminViewer ? 'Citas del paciente' : 'Mis citas',
                style: TextStyle(
                  color: Color(0xFF1A1410),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                proximasCount > 0
                    ? '$proximasCount cita${proximasCount == 1 ? '' : 's'} próxima${proximasCount == 1 ? '' : 's'}'
                    : 'Sin citas próximas por ahora',
                style: const TextStyle(
                  color: Color(0xFF8A6F59),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDE8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8D8C8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _FilterPill(
                        label: 'Próximas',
                        active: _filter == _PatientFilter.proximas,
                        icon: Icons.upcoming_outlined,
                        onTap: () => setState(() => _filter = _PatientFilter.proximas),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _FilterPill(
                        label: 'Historial',
                        active: _filter == _PatientFilter.historial,
                        icon: Icons.history,
                        onTap: () => setState(() => _filter = _PatientFilter.historial),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: appointmentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: OcgColors.espresso),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  isAdminViewer
                      ? 'No se pudieron cargar las citas del paciente.\n$e'
                      : 'No se pudieron cargar tus citas.\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8A6F59)),
                ),
              ),
            ),
            data: (all) {
              final now = DateTime.now();
              final filtered = _filter == _PatientFilter.proximas
                  ? all
                      .where(
                        (a) =>
                            a.fechaHora.isAfter(now) &&
                            a.estado != AppointmentStatus.cancelada &&
                            a.estado != AppointmentStatus.noAsistio &&
                            a.estado != AppointmentStatus.completada,
                      )
                      .toList()
                  : all
                      .where(
                        (a) =>
                            a.fechaHora.isBefore(now) ||
                            a.estado == AppointmentStatus.cancelada ||
                            a.estado == AppointmentStatus.completada ||
                            a.estado == AppointmentStatus.noAsistio,
                      )
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECD9C6)),
                    ),
                    child: Text(
                      _filter == _PatientFilter.proximas
                          ? isAdminViewer
                              ? 'No hay citas próximas para este paciente.\nPulsa + para agendar una nueva cita.'
                              : 'No tienes citas próximas.\nPulsa + para agendar una nueva cita.'
                          : isAdminViewer
                              ? 'Aún no hay citas registradas en el historial del paciente.'
                              : 'Aún no hay citas en tu historial.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A6F59),
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final appt = filtered[i];
                  final canCancel =
                      appt.estado == AppointmentStatus.programada ||
                      appt.estado == AppointmentStatus.confirmada;
                  return _AppointmentTile(
                    appointment: appt,
                    onCancel: canCancel
                        ? () => _handleCancelTap(context, ref, appt)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Stack(
        children: [
          content,
          Positioned(
            bottom: 18,
            right: 16,
            child: _AddAppointmentFab(
              onPressed: () => _showNewAppointmentDialog(
                context,
                ref,
                effectivePatientId,
                appointmentsAsync.asData?.value ?? const [],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdminViewer ? 'Citas del paciente' : 'Mis citas'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: OcgColors.error),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      floatingActionButton: _AddAppointmentFab(
        onPressed: () => _showNewAppointmentDialog(
          context,
          ref,
          effectivePatientId,
          appointmentsAsync.asData?.value ?? const [],
        ),
      ),
      body: content,
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? OcgColors.espresso : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAppointmentFab extends StatelessWidget {
  const _AddAppointmentFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OcgColors.espresso,
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      shadowColor: const Color(0x552C2016),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(Icons.add, color: OcgColors.ivory, size: 28),
        ),
      ),
    );
  }
}

// ─── Tarjeta de cita del paciente ─────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, this.onCancel});

  final AppointmentModel appointment;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor = _estadoColor(appointment.estado);
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    final day = appointment.fechaHora.day.toString().padLeft(2, '0');
    final month = months[appointment.fechaHora.month - 1];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECD9C6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C2016),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 60,
                decoration: BoxDecoration(
                  color: OcgColors.espresso,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      day,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
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
                            _tipoLabel(appointment.tipo),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1A1410),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _estadoLabel(appointment.estado),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 13, color: Color(0xFF8A6F59)),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDateTime(appointment.fechaHora),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6F59)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDE8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (appointment.notas != null && appointment.notas!.trim().isNotEmpty)
                            ? appointment.notas!.trim()
                            : 'Detalle disponible en la cita',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8A6F59),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancelar cita'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcgColors.error,
                  side: const BorderSide(color: OcgColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
