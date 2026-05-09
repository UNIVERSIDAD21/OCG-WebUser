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
import '../../../shared/widgets/ocg_confirm_dialog.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../patients/presentation/patient_viewer_mode.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _bogotaOffset = Duration(hours: 5);

DateTime _toBogota(DateTime dateTime) {
  final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
  return utc.subtract(_bogotaOffset);
}

String _fmtDate(DateTime d) {
  final b = _toBogota(d);
  return '${b.day.toString().padLeft(2, '0')}/'
      '${b.month.toString().padLeft(2, '0')}/${b.year}';
}

String _fmtDateTime(DateTime d) {
  final b = _toBogota(d);
  final hour12 = b.hour % 12 == 0 ? 12 : b.hour % 12;
  final suffix = b.hour >= 12 ? 'PM' : 'AM';
  return '${_fmtDate(d)} a las '
      '${hour12.toString().padLeft(2, '0')}:'
      '${b.minute.toString().padLeft(2, '0')} $suffix';
}

String _fmtClinicWallDateTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} a las '
      '${hour12.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')} $suffix';
}

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

class _AppointmentStatusStyle {
  const _AppointmentStatusStyle({
    required this.color,
    required this.softBackground,
    required this.icon,
  });

  final Color color;
  final Color softBackground;
  final IconData icon;
}

_AppointmentStatusStyle _appointmentStatusStyle(AppointmentStatus status) {
  const activeBlue = Color(0xFF1565C0);
  return switch (status) {
    AppointmentStatus.programada => _AppointmentStatusStyle(
      color: activeBlue,
      softBackground: Color(0xFFEAF3FF),
      icon: Icons.calendar_month_outlined,
    ),
    AppointmentStatus.confirmada => _AppointmentStatusStyle(
      color: activeBlue,
      softBackground: Color(0xFFEAF3FF),
      icon: Icons.verified_outlined,
    ),
    AppointmentStatus.reprogramada => _AppointmentStatusStyle(
      color: Color(0xFF7E3AF2),
      softBackground: Color(0xFFF1E8FF),
      icon: Icons.event_repeat_outlined,
    ),
    AppointmentStatus.completada => _AppointmentStatusStyle(
      color: OcgColors.success,
      softBackground: Color(0xFFEAF7EE),
      icon: Icons.task_alt,
    ),
    AppointmentStatus.cancelada => _AppointmentStatusStyle(
      color: OcgColors.error,
      softBackground: Color(0xFFFCECEC),
      icon: Icons.cancel_outlined,
    ),
    AppointmentStatus.noAsistio => _AppointmentStatusStyle(
      color: OcgColors.warning,
      softBackground: Color(0xFFFFF4E5),
      icon: Icons.person_off_outlined,
    ),
  };
}

bool _isActiva(AppointmentModel a) => switch (a.estado) {
  AppointmentStatus.programada || AppointmentStatus.confirmada => true,
  _ => false,
};

bool _isCompletada(AppointmentModel a) =>
    a.estado == AppointmentStatus.completada;

bool _isIncidencia(AppointmentModel a) => switch (a.estado) {
  AppointmentStatus.cancelada ||
  AppointmentStatus.noAsistio ||
  AppointmentStatus.reprogramada => true,
  _ => false,
};

enum _PatientFilter { activas, completadas, incidencias }

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
    extends ConsumerState<PatientAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  _PatientFilter _filter = _PatientFilter.activas;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeSlide =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
    bool expandMorning = false;
    bool expandAfternoon = false;

    AppointmentType selectedType = AppointmentType.valoracion;
    final bogotaNow = AppointmentsBusinessRules.toBogota(DateTime.now());
    DateTime selectedDateTime = AppointmentsBusinessRules.fromBogotaComponents(
      year: bogotaNow.year,
      month: bogotaNow.month,
      day: bogotaNow.day + 1,
      hour: AppointmentsBusinessRules.workdayStartHour,
      minute: 0,
    );
    String? errorMsg;
    bool saving = false;
    var selectedDayKey = AppointmentsBusinessRules.dayKeyBogota(
      selectedDateTime,
    );
    var availabilityStream = ref
        .read(availabilityRepositoryProvider)
        .watchAvailabilityByDay(selectedDayKey);

    DateTime dateFromSlotKey(DateTime baseDay, String slotKey) {
      return AppointmentsBusinessRules.dateTimeFromDayAndSlotKeyBogota(
        dayReference: baseDay,
        slotKey: slotKey,
      );
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
                      _fmtClinicWallDateTime(selectedDateTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OcgColors.espresso,
                      ),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(
                          bogotaNow.year,
                          bogotaNow.month,
                          bogotaNow.day,
                        ),
                        lastDate: DateTime(
                          bogotaNow.year,
                          bogotaNow.month,
                          bogotaNow.day,
                        ).add(const Duration(days: 90)),
                      );
                      if (pickedDate == null) return;
                      setDs(() {
                        selectedDateTime =
                            AppointmentsBusinessRules.fromBogotaComponents(
                              year: pickedDate.year,
                              month: pickedDate.month,
                              day: pickedDate.day,
                              hour: AppointmentsBusinessRules.workdayStartHour,
                              minute: 0,
                            );
                        selectedDayKey = AppointmentsBusinessRules.dayKeyBogota(
                          selectedDateTime,
                        );
                        availabilityStream = ref
                            .read(availabilityRepositoryProvider)
                            .watchAvailabilityByDay(selectedDayKey);
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
                    stream: availabilityStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final availability = snapshot.data;
                      final orderedSlots =
                          AppointmentsBusinessRules.buildAllWorkdaySlots(
                              day: selectedDateTime,
                              stepMinutes:
                                  AppointmentsBusinessRules.slotStepMinutes,
                            ).toList()
                            ..sort((a, b) => a.start.compareTo(b.start));
                      final allLabels = orderedSlots
                          .map(
                            (s) =>
                                AppointmentsBusinessRules.slotKeyFromDateTime(
                                  s.start,
                                ),
                          )
                          .toList();

                      const operationalMinutes =
                          30 +
                          AppointmentsBusinessRules
                              .bufferMinutesBetweenAppointments;

                      bool isStartAvailable(String label) {
                        if (snapshot.hasError) return false;

                        final start = dateFromSlotKey(selectedDateTime, label);
                        final notPastError =
                            AppointmentsBusinessRules.validateStartNotInPast(
                              start: start,
                            );
                        if (notPastError != null) return false;

                        final fitsWorkingHours =
                            AppointmentsBusinessRules.validateWithinWorkingHours(
                              start: start,
                              durationMinutes: operationalMinutes,
                            ) ==
                            null;
                        if (!fitsWorkingHours) return false;

                        if (availability == null) return true;

                        final end = start.add(
                          const Duration(minutes: operationalMinutes),
                        );
                        for (final slotLabel in allLabels) {
                          final slotStart = dateFromSlotKey(
                            selectedDateTime,
                            slotLabel,
                          );
                          final slotEnd = slotStart.add(
                            Duration(
                              minutes:
                                  AppointmentsBusinessRules.slotStepMinutes,
                            ),
                          );
                          final overlaps =
                              slotStart.isBefore(end) &&
                              start.isBefore(slotEnd);
                          if (overlaps &&
                              availability.slots[slotLabel] == false) {
                            return false;
                          }
                        }

                        return true;
                      }

                      final availableLabels = allLabels
                          .where(isStartAvailable)
                          .toList();

                      if (availableLabels.isEmpty) {
                        return const Text(
                          'No hay horarios disponibles para ese día.',
                          style: TextStyle(color: OcgColors.error),
                        );
                      }

                      final morningLabels = availableLabels.where((label) {
                        final d = dateFromSlotKey(selectedDateTime, label);
                        return d.hour < 12;
                      }).toList();
                      final afternoonLabels = availableLabels.where((label) {
                        final d = dateFromSlotKey(selectedDateTime, label);
                        return d.hour >= 12;
                      }).toList();

                      Widget buildSlotChip(String label) {
                        final slotDate = dateFromSlotKey(
                          selectedDateTime,
                          label,
                        );
                        return ChoiceChip(
                          label: Text(
                            AppointmentsBusinessRules.displayLabelFromSlotKey(
                              label,
                            ),
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
                            border: Border.all(
                              color: OcgColors.bronze.withOpacity(0.22),
                            ),
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
                                      expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
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
                                    children: labels
                                        .map(buildSlotChip)
                                        .toList(),
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
                            onToggle: () =>
                                setDs(() => expandMorning = !expandMorning),
                            labels: morningLabels,
                          ),
                          buildPeriodSection(
                            title: 'Tarde',
                            expanded: expandAfternoon,
                            onToggle: () =>
                                setDs(() => expandAfternoon = !expandAfternoon),
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

                      final notPastError =
                          AppointmentsBusinessRules.validateStartNotInPast(
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
                            .getAvailabilityByDay(
                              AppointmentsBusinessRules.dayKeyBogota(
                                selectedDateTime,
                              ),
                            );

                        if (availability != null) {
                          const operationalMinutes =
                              30 +
                              AppointmentsBusinessRules
                                  .bufferMinutesBetweenAppointments;
                          final end = selectedDateTime.add(
                            const Duration(minutes: operationalMinutes),
                          );

                          final allLabels =
                              AppointmentsBusinessRules.buildAllWorkdaySlots(
                                day: selectedDateTime,
                                stepMinutes:
                                    AppointmentsBusinessRules.slotStepMinutes,
                              ).map(
                                (s) =>
                                    AppointmentsBusinessRules.slotKeyFromDateTime(
                                      s.start,
                                    ),
                              );

                          bool stillAvailable = true;
                          for (final label in allLabels) {
                            final slotStart = dateFromSlotKey(
                              selectedDateTime,
                              label,
                            );
                            final slotEnd = slotStart.add(
                              Duration(
                                minutes:
                                    AppointmentsBusinessRules.slotStepMinutes,
                              ),
                            );
                            final overlaps =
                                slotStart.isBefore(end) &&
                                selectedDateTime.isBefore(slotEnd);
                            if (overlaps &&
                                availability.slots[label] == false) {
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

  Future<void> _handleCancelTap(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
  ) async {
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
    final confirmed = await OcgConfirmDialog.show(
      context,
      type: OcgConfirmDialogType.danger,
      title: '¿Cancelar esta cita?',
      message: 'Cita del ${_fmtDateTime(appt.fechaHora)}.\nEsta acción no se puede deshacer.',
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'No, mantenerla',
      onConfirm: () {},
    );

    if (confirmed != true) return;

    try {
      final currentUser = ref.read(authStateProvider).asData?.value;
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(
            appt.id,
            AppointmentStatus.cancelada,
            actorRole: 'patient',
            actorUserId: currentUser?.uid,
            updatedByRole: 'patient',
            updatedBy: currentUser?.uid,
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

    final appointmentsAsync = ref.watch(
      patientAppointmentsProvider(effectivePatientId),
    );

    final allAppointments =
        appointmentsAsync.asData?.value ?? const <AppointmentModel>[];
    final activasCount = allAppointments.where(_isActiva).length;
    final completadasCount = allAppointments.where(_isCompletada).length;
    final incidenciasCount = allAppointments.where(_isIncidencia).length;

    final content = Column(
      children: [
        _HeroHeader(
          isAdminViewer: isAdminViewer,
          activasCount: activasCount,
          completadasCount: completadasCount,
          incidenciasCount: incidenciasCount,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FilterBar(
              filter: _filter,
              activasCount: activasCount,
              completadasCount: completadasCount,
              incidenciasCount: incidenciasCount,
              onChanged: (f) => setState(() => _filter = f)),
        ),
        Expanded(
          child: appointmentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: OcgColors.espresso),
            ),
            error: (e, _) => Center(
              child: OcgEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'No se pudieron cargar las citas',
                  subtitle: '$e'),
            ),
            data: (all) {
              final filtered = switch (_filter) {
                _PatientFilter.activas => all.where(_isActiva).toList(),
                _PatientFilter.completadas => all.where(_isCompletada).toList(),
                _PatientFilter.incidencias => all.where(_isIncidencia).toList(),
              };

              filtered.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

              if (filtered.isEmpty) {
                return Center(
                  child: OcgEmptyState(
                    icon: switch (_filter) {
                      _PatientFilter.activas => Icons.calendar_month_outlined,
                      _PatientFilter.completadas => Icons.task_alt,
                      _PatientFilter.incidencias => Icons.warning_amber_outlined,
                    },
                    title: switch (_filter) {
                      _PatientFilter.activas => 'No hay citas activas',
                      _PatientFilter.completadas => 'Aún no hay citas completadas',
                      _PatientFilter.incidencias => 'Sin incidencias registradas',
                    },
                    subtitle: _filter == _PatientFilter.activas
                        ? 'Pulsa + para agendar una nueva cita'
                        : null,
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
                  return _ApptCard(
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
      return FadeTransition(
        opacity: _fadeSlide,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(_fadeSlide),
          child: Stack(
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
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: SafeArea(
        child: Stack(
          children: [
            const _Blob(top: -60, right: -40, size: 180, color: Color(0x30C8AF8C)),
            const _Blob(bottom: -40, left: -30, size: 140, color: Color(0x22B49B78)),
            FadeTransition(
              opacity: _fadeSlide,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(_fadeSlide),
                child: content,
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

class _ApptCard extends StatelessWidget {
  const _ApptCard({required this.appointment, this.onCancel});
  final AppointmentModel appointment;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = _appointmentStatusStyle(appointment.estado);
    final statusColor = s.color;
    final local = _toBogota(appointment.fechaHora);
    final day = local.day.toString().padLeft(2, '0');
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final month = months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFFFFFCF8), s.softBackground.withOpacity(0.25)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2C2016).withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date badge with gradient
          Container(
            width: 56, height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [statusColor, statusColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(month,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Text(day,
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w800, height: 1.05)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: s.softBackground, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.icon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(_estadoLabel(appointment.estado),
                        style: TextStyle(color: statusColor, fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 14, color: statusColor.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(timeStr,
                    style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text(_tipoLabel(appointment.tipo),
                  style: const TextStyle(color: Color(0xFF1A1410), fontSize: 15,
                      fontWeight: FontWeight.w700)),
              if (appointment.notas != null && appointment.notas!.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                  child: Text(appointment.notas!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F59))),
                ),
              ],
              if (onCancel != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancelar cita'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OcgColors.error,
                      side: const BorderSide(color: OcgColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Hero header ────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isAdminViewer,
      required this.activasCount, required this.completadasCount, required this.incidenciasCount});
  final bool isAdminViewer;
  final int activasCount, completadasCount, incidenciasCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF2C2016), Color(0xFF4A3628), Color(0xFF2C2016)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC8AF8C), Color(0xFFA88F6E)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAdminViewer ? 'Citas del paciente' : 'Mis citas',
                  style: const TextStyle(color: OcgColors.ivory, fontSize: 20,
                      fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Text(
                  isAdminViewer
                      ? 'Filtra por estado clínico para gestionar'
                      : 'Organiza tus citas por estado real',
                  style: TextStyle(color: OcgColors.ivory.withOpacity(0.65), fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _Kpi(label: 'Activas', value: activasCount, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 8),
          _Kpi(label: 'Completadas', value: completadasCount, color: const Color(0xFF81C784)),
          const SizedBox(width: 8),
          _Kpi(label: 'Incidencias', value: incidenciasCount, color: const Color(0xFFEF9A9A)),
        ]),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: OcgColors.ivory.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OcgColors.ivory.withOpacity(0.12))),
        child: Column(children: [
          Text('$value',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(color: OcgColors.ivory.withOpacity(0.6), fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Filter bar ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.activasCount,
      required this.completadasCount, required this.incidenciasCount, required this.onChanged});
  final _PatientFilter filter;
  final int activasCount, completadasCount, incidenciasCount;
  final ValueChanged<_PatientFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7DDD2).withOpacity(0.5)),
          boxShadow: [BoxShadow(color: const Color(0xFF2C2016).withOpacity(0.03),
              blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        _Pill(
            filter: _PatientFilter.activas, current: filter, label: 'Activas',
            count: activasCount, icon: Icons.upcoming_outlined,
            onTap: () => onChanged(_PatientFilter.activas)),
        const SizedBox(width: 4),
        _Pill(
            filter: _PatientFilter.completadas, current: filter, label: 'Completadas',
            count: completadasCount, icon: Icons.task_alt,
            onTap: () => onChanged(_PatientFilter.completadas)),
        const SizedBox(width: 4),
        _Pill(
            filter: _PatientFilter.incidencias, current: filter, label: 'Incidencias',
            count: incidenciasCount, icon: Icons.warning_amber_outlined,
            onTap: () => onChanged(_PatientFilter.incidencias)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.filter, required this.current, required this.label,
      required this.count, required this.icon, required this.onTap});
  final _PatientFilter filter, current;
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  bool get active => filter == current;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2C2016) : const Color(0xFFF7F3EC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? const Color(0xFF2C2016) : const Color(0xFFE7DDD2), width: active ? 1 : 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15,
                color: active ? OcgColors.ivory : const Color(0xFF8A6F59)),
            const SizedBox(width: 5),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(label,
                    style: TextStyle(
                        color: active ? OcgColors.ivory : const Color(0xFF8A6F59),
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: active
                      ? OcgColors.ivory.withOpacity(0.18)
                      : const Color(0xFF2C2016).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('$count',
                  style: TextStyle(
                      color: active ? OcgColors.ivory : const Color(0xFF2C2016),
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Blob ───────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final double? top, right, bottom, left;
  final double size;
  final Color color;
  const _Blob({this.top, this.right, this.bottom, this.left,
      required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, right: right, bottom: bottom, left: left,
      child: IgnorePointer(
        child: Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [color, color.withOpacity(0)], stops: const [0, 0.7]))),
      ),
    );
  }
}
