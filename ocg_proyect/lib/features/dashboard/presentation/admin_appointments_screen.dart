import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/data/models/availability_day_model.dart';
import '../../appointments/data/models/urgency_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/providers/availability_provider.dart';
import '../../appointments/providers/urgency_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../../treatment/providers/patient_treatments_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../shared/widgets/ocg_logout_dialog.dart';
import '../../../shared/widgets/ocg_segmented_tabs.dart';
import '../../../shared/widgets/ocg_loading_state.dart';
import '../../../shared/widgets/ocg_photo_viewer.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import 'admin_appointments_agenda_helpers.dart';
import 'admin_appointments_formatters.dart';
import 'widgets/time_grid_view.dart';
import 'widgets/month_calendar_widget.dart';
import '../../admin/presentation/web/layout/admin_desktop_layout.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/components/action_toolbar.dart';
import '../../admin/presentation/web/components/page_header.dart';

// ─── AdminAppointmentsScreen ──────────────────────────────────────────────────

class AdminAppointmentsDesktopTestHarness extends StatelessWidget {
  const AdminAppointmentsDesktopTestHarness({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final panelGap = layout?.panelGap ?? 12;
    final tier = layout?.tier ?? AdminDesktopTier.standard;
    final shouldSplit =
        layout?.shouldKeepSplit(primaryMinWidth: 300, secondaryMinWidth: 420) ??
        true;
    final calendarWidth = switch (tier) {
      AdminDesktopTier.wide => 320.0,
      AdminDesktopTier.standard => 300.0,
      AdminDesktopTier.compact => 280.0,
      AdminDesktopTier.tight => 0.0,
    };

    final calendarCard = Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Agenda'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: shouldSplit ? 1.12 : 1.25,
            children: List.generate(
              14,
              (index) => Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}'),
              ),
            ),
          ),
        ],
      ),
    );

    final detailPanel = Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle de agenda'),
          SizedBox(height: 8),
          Text('Citas del día y acciones operativas'),
        ],
      ),
    );

    if (shouldSplit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: calendarWidth, child: calendarCard),
          SizedBox(width: panelGap),
          Expanded(child: detailPanel),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          calendarCard,
          SizedBox(height: panelGap),
          detailPanel,
        ],
      ),
    );
  }
}

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({
    super.key,
    this.embeddedInMobileShell = false,
  });

  final bool embeddedInMobileShell;

  // ─── Diálogo crear cita ───────────────────────────────────────────────────
  //
  // ✅ FIX ARQUITECTURAL: ya no se usa Consumer + StatefulBuilder anidados.
  //    El diálogo es ahora un ConsumerStatefulWidget propio (_CreateApptDialog)
  //    que maneja su estado y sus providers limpiamente, sin que un rebuild
  //    externo del stream pueda corromper el árbol de layout del diálogo.

  static Future<void> showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    DateTime? baseDate,
    PatientModel? preselectedPatient,
    List<AppointmentModel> existingAppointments = const [],
    UrgencyRequestModel? urgencyRequest,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateApptDialog(
        baseDate: baseDate,
        preselectedPatient: preselectedPatient,
        existingAppointments: existingAppointments,
        urgencyRequest: urgencyRequest,
        // Pasamos el ref del caller para poder escribir en Firestore
        callerRef: ref,
      ),
    );
  }

  // ─── Diálogo crear cuenta de paciente ─────────────────────────────────────

  static Future<void> showCreatePatientAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMsg;
    String name = '';
    String email = '';
    String pass = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDs) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: OcgColors.espresso),
              SizedBox(width: 10),
              Expanded(child: Text('Crear cuenta de paciente')),
            ],
          ),
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
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    onChanged: (v) => name = v,
                    validator: Validators.fullName,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onChanged: (v) => email = v,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña temporal',
                      prefixIcon: Icon(Icons.lock_outlined),
                      helperText: 'El paciente puede cambiarla desde la app',
                    ),
                    onChanged: (v) => pass = v,
                    validator: Validators.passwordForRegister,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'El tratamiento se configurará después desde el perfil del paciente.',
                      style: Theme.of(dialogCtx).textTheme.bodySmall,
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: OcgColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: OcgColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: OcgColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => popDialog(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.espresso,
                foregroundColor: OcgColors.ivory,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDs(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });
                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .createPatientByAdmin(
                              email: email.trim(),
                              password: pass,
                              displayName: name.trim(),
                            );
                        ref.invalidate(patientsStreamProvider);
                        ref.invalidate(filteredPatientsProvider);
                        final nombre = name.trim();
                        popDialog(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Cuenta creada para $nombre.'),
                              duration: const Duration(seconds: 4),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        }
                      } on FirebaseFunctionsException catch (e) {
                        final msg =
                            e.message ??
                            (e.code == 'already-exists'
                                ? 'Este correo ya tiene una cuenta registrada.'
                                : 'No se pudo crear la cuenta del paciente.');
                        setDs(() {
                          errorMsg = msg;
                          isSubmitting = false;
                        });
                      } catch (e) {
                        setDs(() {
                          errorMsg = 'Error inesperado: $e';
                          isSubmitting = false;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OcgColors.ivory,
                      ),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

// ─── _CreateApptDialog ────────────────────────────────────────────────────────
//
// ✅ ConsumerStatefulWidget propio para el diálogo de crear cita.
//    Ventajas sobre Consumer + StatefulBuilder:
//    - ref.watch() funciona directamente en build() sin anidamientos
//    - El stream de pacientes puede actualizar sin destruir el árbol completo
//    - Los controladores se disponen limpiamente en dispose()
//    - No hay conflictos de layout entre Consumer rebuild y StatefulBuilder

class _CreateApptDialog extends ConsumerStatefulWidget {
  const _CreateApptDialog({
    required this.callerRef,
    required this.existingAppointments,
    this.baseDate,
    this.preselectedPatient,
    this.urgencyRequest,
  });

  final WidgetRef callerRef;
  final List<AppointmentModel> existingAppointments;
  final DateTime? baseDate;
  final PatientModel? preselectedPatient;
  final UrgencyRequestModel? urgencyRequest;

  @override
  ConsumerState<_CreateApptDialog> createState() => _CreateApptDialogState();
}

class _CreateApptDialogState extends ConsumerState<_CreateApptDialog> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _notesCtrl;

  PatientModel? _selectedPatient;
  String? _selectedTreatmentId;
  final int _durationMinutes = 30;
  late DateTime _dateTime;
  bool _saving = false;
  bool _expandMorning = true;
  bool _expandAfternoon = true;
  String? _errorMsg;

  bool get _isUrgencyBooking => widget.urgencyRequest != null;

  DateTime _roundUpToNextSlot(DateTime value) {
    final withLeadTime = value.add(const Duration(minutes: 15));
    final roundedMinute = withLeadTime.minute <= 30 ? 30 : 0;
    final roundedHour = withLeadTime.minute <= 30
        ? withLeadTime.hour
        : withLeadTime.hour + 1;
    return DateTime(
      withLeadTime.year,
      withLeadTime.month,
      withLeadTime.day,
      roundedHour,
      roundedMinute,
    );
  }

  DateTime _initialDateTime() {
    final base = widget.baseDate;
    if (base != null) {
      final fromBase = DateTime(base.year, base.month, base.day, 10);
      if (fromBase.isAfter(DateTime.now())) return fromBase;
    }

    final nextSlot = _roundUpToNextSlot(DateTime.now());
    if (_isUrgencyBooking) return nextSlot;
    return _nextWorkingSlotFrom(nextSlot);
  }

  DateTime _nextWorkingSlotFrom(DateTime from) {
    final firstDay = DateTime(from.year, from.month, from.day);
    for (var dayOffset = 0; dayOffset < 21; dayOffset++) {
      final day = firstDay.add(Duration(days: dayOffset));
      for (final block in AppointmentsBusinessRules.scheduleBlocksForDay(day)) {
        final blockStart = DateTime(
          day.year,
          day.month,
          day.day,
          block.startHour,
        );
        final blockEnd = DateTime(day.year, day.month, day.day, block.endHour);
        final candidate = dayOffset == 0 && from.isAfter(blockStart)
            ? from
            : blockStart;
        if (!candidate
            .add(Duration(minutes: _durationMinutes))
            .isAfter(blockEnd)) {
          return candidate;
        }
      }
    }

    return DateTime(
      from.year,
      from.month,
      from.day + 1,
      AppointmentsBusinessRules.workdayStartHour,
    );
  }

  PatientModel _patientFromUrgency(UrgencyRequestModel urgency) {
    return PatientModel.fromJson({
      'id': urgency.patientId,
      'uid': urgency.patientId,
      'nombre': urgency.patientName,
      'telefono': urgency.patientPhone,
      'etapaActual': TreatmentStage.valoracionInicial.name,
      'fechaInicio': DateTime.now(),
      'notasClinicas': '',
      'totalTratamiento': 0,
      'saldoPendiente': 0,
    });
  }

  @override
  void initState() {
    super.initState();
    _dateTime = _initialDateTime();
    final urgency = widget.urgencyRequest;
    _selectedPatient =
        widget.preselectedPatient ??
        (urgency == null ? null : _patientFromUrgency(urgency));
    _searchCtrl = TextEditingController(text: _selectedPatient?.nombre ?? '');
    _notesCtrl = TextEditingController(
      text: urgency == null
          ? ''
          : 'Solicitud de urgencia: ${urgency.descripcion}',
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<AppointmentTimeSlot> _slotsForCurrentDay([
    AvailabilityDayModel? availability,
  ]) {
    final base = AppointmentsBusinessRules.buildDailySlots(
      day: _dateTime,
      existingAppointments: widget.existingAppointments,
      durationMinutes: _durationMinutes,
      stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
    );

    final now = DateTime.now();
    final notPast = base.where((slot) => slot.start.isAfter(now)).toList();
    if (_isUrgencyBooking) {
      return notPast
          .map(
            (slot) => AppointmentTimeSlot(start: slot.start, isAvailable: true),
          )
          .toList();
    }

    if (availability == null) return notPast;

    return notPast
        .map(
          (slot) => AppointmentTimeSlot(
            start: slot.start,
            isAvailable:
                slot.isAvailable && availability.isSlotAvailable(slot.label),
          ),
        )
        .toList();
  }

  bool _isWritableTreatment(PatientTreatment treatment) =>
      !treatment.id.startsWith('legacy-primary-');

  List<PatientTreatment> _writableTreatments(
    List<PatientTreatment> treatments,
  ) {
    return treatments.where(_isWritableTreatment).toList();
  }

  PatientTreatment? _resolveSelectedTreatment(
    List<PatientTreatment> treatments,
  ) {
    final writable = _writableTreatments(treatments);
    if (writable.isEmpty) return null;

    final selectedId = _selectedTreatmentId;
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final treatment in writable) {
        if (treatment.id == selectedId) return treatment;
      }
    }

    for (final treatment in writable) {
      if (treatment.isPrimary && treatment.isActive) return treatment;
    }
    for (final treatment in writable) {
      if (treatment.isActive) return treatment;
    }
    for (final treatment in writable) {
      if (treatment.isPrimary) return treatment;
    }
    return writable.first;
  }

  TreatmentStage _appointmentStage(PatientTreatment? treatment) {
    if (_isUrgencyBooking) return TreatmentStage.valoracionInicial;
    return treatment?.etapaActual ??
        _selectedPatient?.etapaActual ??
        TreatmentStage.valoracionInicial;
  }

  AppointmentType? _appointmentTypeFor(PatientTreatment? treatment) {
    if (_isUrgencyBooking) return AppointmentType.urgencia;
    final patient = _selectedPatient;
    if (patient == null) return null;
    return AppointmentsBusinessRules.appointmentTypeForStage(
      _appointmentStage(treatment),
    );
  }

  void _selectPatient(PatientModel patient) {
    if (_isUrgencyBooking) return;
    _selectedPatient = patient;
    _selectedTreatmentId = null;
    _searchCtrl.text = patient.nombre;
    _errorMsg = null;
  }

  void _clearSelectedPatient() {
    if (_isUrgencyBooking) return;
    _selectedPatient = null;
    _selectedTreatmentId = null;
    _searchCtrl.clear();
    _errorMsg = null;
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    TimeOfDay? pickedTime;
    if (_isUrgencyBooking && mounted) {
      pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dateTime),
      );
    }

    setState(() {
      _dateTime = DateTime(
        d.year,
        d.month,
        d.day,
        pickedTime?.hour ?? AppointmentsBusinessRules.workdayStartHour,
        pickedTime?.minute ?? 0,
      );
      _errorMsg = null;
    });
  }

  Widget _flowInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = OcgColors.bronze,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: OcgColors.ink.withOpacity(0.74),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotLegend() {
    Widget item(Color color, String label, {bool outlined = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color, width: outlined ? 2 : 1),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: OcgColors.ink.withOpacity(0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(OcgColors.sand, 'Seleccionado'),
        item(const Color(0xFF7A8A20), 'Disponible', outlined: true),
        item(Colors.grey.shade500, 'Ocupado/no laborable'),
      ],
    );
  }

  Widget _slotAvailabilitySummary(List<AppointmentTimeSlot> slots) {
    if (_isUrgencyBooking) {
      final notPastError = AppointmentsBusinessRules.validateStartNotInPast(
        start: _dateTime,
      );
      final isReady = notPastError == null;
      return _flowInfoCard(
        icon: isReady
            ? Icons.priority_high_rounded
            : Icons.warning_amber_outlined,
        title: isReady
            ? 'Horario de urgencia listo'
            : 'Selecciona un horario futuro',
        subtitle:
            'Seleccionado: ${appointmentFmtDateTime(_dateTime)}. Si hay conflicto, se pedirá confirmación manual.',
        color: isReady ? const Color(0xFF2E7D32) : OcgColors.error,
      );
    }

    final total = slots.length;
    final available = slots.where((s) => s.isAvailable).length;
    final blocked = total - available;
    final selectedAvailable = slots.any(
      (s) => s.start == _dateTime && s.isAvailable,
    );
    final color = selectedAvailable ? const Color(0xFF2E7D32) : OcgColors.error;
    return _flowInfoCard(
      icon: selectedAvailable
          ? Icons.event_available_outlined
          : Icons.warning_amber_outlined,
      title: selectedAvailable
          ? 'Horario listo para agendar'
          : 'Elige un horario disponible',
      subtitle:
          '$available disponibles · $blocked bloqueados. Seleccionado: ${appointmentFmtDateTime(_dateTime)}.',
      color: color,
    );
  }

  Future<void> _submit(PatientTreatment? selectedTreatment) async {
    if (_selectedPatient == null) {
      setState(() => _errorMsg = 'Selecciona un paciente de la lista.');
      return;
    }
    final effectiveType = _appointmentTypeFor(selectedTreatment);
    final effectiveStage = _appointmentStage(selectedTreatment);
    if (effectiveType == null) {
      setState(
        () => _errorMsg =
            'No se pudo determinar el tipo de cita para la fase actual del paciente.',
      );
      return;
    }
    final notPastError = AppointmentsBusinessRules.validateStartNotInPast(
      start: _dateTime,
    );
    if (notPastError != null) {
      setState(() => _errorMsg = notPastError);
      return;
    }

    final workingHoursError = _isUrgencyBooking
        ? null
        : AppointmentsBusinessRules.validateWithinWorkingHours(
            start: _dateTime,
            durationMinutes: _durationMinutes,
          );
    if (workingHoursError != null) {
      setState(() => _errorMsg = workingHoursError);
      return;
    }

    final hasConflict = AppointmentsBusinessRules.hasTimeConflict(
      existingAppointments: widget.existingAppointments,
      newStart: _dateTime,
      durationMinutes: _durationMinutes,
    );
    if (hasConflict && !_isUrgencyBooking) {
      setState(
        () => _errorMsg =
            'Ese horario está ocupado o dentro del buffer de 10 min.',
      );
      return;
    }
    if (hasConflict && _isUrgencyBooking) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar cita de urgencia'),
          content: const Text(
            'Hay otra cita en ese horario. Para urgencias puedes confirmar de todas formas.',
          ),
          actions: [
            TextButton(
              onPressed: () => popDialog(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => popDialog(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });
    final notasTexto = _notesCtrl.text.trim();
    try {
      if (_isUrgencyBooking) {
        final adminId =
            ref.read(authStateProvider).asData?.value?.uid ?? 'admin';
        // Bloque 5: usar createAppointmentFromUrgency que bypassa validaciones
        // y actualiza la urgencia en un solo batch atómico
        final urgencyAppointment = AppointmentModel(
          id: '',
          patientId: _selectedPatient!.id,
          patientName: _selectedPatient!.nombre,
          patientPhone: _selectedPatient!.telefono,
          treatmentId: selectedTreatment?.id,
          treatmentNameSnapshot: selectedTreatment?.displayName,
          creadoPor: adminId,
          tipo: effectiveType,
          estado: AppointmentStatus.programada,
          fechaHora: _dateTime,
          duracionMinutos: _durationMinutes,
          notas: notasTexto.isEmpty ? null : notasTexto,
          stageId: effectiveStage,
          stageNameSnapshot: stageNames[effectiveStage] ?? effectiveStage.name,
        );
        await widget.callerRef
            .read(urgencyRepositoryProvider)
            .createAppointmentFromUrgency(
              request: widget.urgencyRequest!,
              appointment: urgencyAppointment,
              adminId: adminId,
              adminNotes: notasTexto.isEmpty ? null : notasTexto,
            );
      } else {
        await widget.callerRef
            .read(appointmentsRepositoryProvider)
            .createAppointment(
              AppointmentModel(
                id: '',
                patientId: _selectedPatient!.id,
                patientName: _selectedPatient!.nombre,
                patientPhone: _selectedPatient!.telefono,
                treatmentId: selectedTreatment?.id,
                treatmentNameSnapshot: selectedTreatment?.displayName,
                creadoPor: 'admin',
                tipo: effectiveType,
                estado: AppointmentStatus.programada,
                fechaHora: _dateTime,
                duracionMinutos: _durationMinutes,
                notas: notasTexto.isEmpty ? null : notasTexto,
                stageId: effectiveStage,
                stageNameSnapshot:
                    stageNames[effectiveStage] ?? effectiveStage.name,
              ),
            );
      }
      popDialog(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cita creada.')));
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMsg = e.toString().contains('SLOT_TAKEN')
            ? 'Ese horario ya está ocupado. Elige otro.'
            : 'No se pudo crear: $e';
      });
    }
  }

  Widget _patientAvatar(PatientModel patient) {
    final url = (patient.fotoUrl ?? '').trim();
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 17,
        backgroundImage: NetworkImage(url),
        backgroundColor: OcgColors.bronze.withOpacity(0.15),
        onBackgroundImageError: (_, __) {},
      );
    }
    return const CircleAvatar(
      radius: 17,
      backgroundColor: OcgColors.espresso,
      child: Icon(Icons.person, size: 17, color: OcgColors.ivory),
    );
  }

  Widget _treatmentAssociationCard({
    required List<PatientTreatment> treatments,
    required PatientTreatment? selectedTreatment,
  }) {
    if (_selectedPatient == null) return const SizedBox.shrink();

    if (treatments.isEmpty) {
      return _flowInfoCard(
        icon: Icons.link_off_outlined,
        title: 'Cita sin tratamiento asociado',
        subtitle:
            'Este paciente no tiene tratamientos nuevos disponibles. La cita queda en modo legacy hasta crear o migrar un tratamiento.',
        color: const Color(0xFF9A5B2C),
      );
    }

    if (treatments.length == 1) {
      final treatment = treatments.first;
      return _flowInfoCard(
        icon: Icons.medical_services_outlined,
        title: 'Tratamiento asociado',
        subtitle:
            '${treatment.displayName} - ${stageNames[treatment.etapaActual] ?? treatment.etapaActual.name}',
        color: OcgColors.bronze,
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedTreatment?.id,
      decoration: const InputDecoration(
        labelText: 'Tratamiento asociado',
        prefixIcon: Icon(Icons.medical_services_outlined),
        helperText: 'Obligatorio cuando el paciente tiene varios tratamientos.',
      ),
      items: treatments
          .map(
            (treatment) => DropdownMenuItem<String>(
              value: treatment.id,
              child: Text(
                treatment.isPrimary
                    ? '${treatment.displayName} - principal'
                    : treatment.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (value) => setState(() {
              _selectedTreatmentId = value;
              _errorMsg = null;
            }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ref.watch() aquí — si el stream emite, solo rebuild este widget,
    //    sin destruir ni recrear el árbol del AlertDialog.
    final patients =
        ref.watch(patientsStreamProvider).asData?.value ?? const [];
    final availability = ref
        .watch(availabilityByDayProvider(appointmentDayKey(_dateTime)))
        .asData
        ?.value;
    final selectedPatient = _selectedPatient;
    final treatments = selectedPatient == null
        ? const <PatientTreatment>[]
        : ref.watch(
            effectivePatientTreatmentsProvider((
              patientId: selectedPatient.id,
              patient: selectedPatient,
            )),
          );
    final writableTreatments = _writableTreatments(treatments);
    final selectedTreatment = _resolveSelectedTreatment(treatments);
    final effectiveStage = _appointmentStage(selectedTreatment);
    final effectiveType = _appointmentTypeFor(selectedTreatment);

    // Lista filtrada — solo se calcula en build, no en StatefulBuilder
    final filtered = _searchCtrl.text.isEmpty
        ? patients
        : patients
              .where(
                (p) => p.nombre.toLowerCase().contains(
                  _searchCtrl.text.toLowerCase(),
                ),
              )
              .toList();

    final showDropdown =
        _searchCtrl.text.isNotEmpty && _selectedPatient == null;

    return AlertDialog(
      title: Text(_isUrgencyBooking ? 'Nueva cita de urgencia' : 'Nueva cita'),
      content: SizedBox(
        // ✅ Ancho fijo evita que IntrinsicWidth falle con el dropdown
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isUrgencyBooking) ...[
                _flowInfoCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Citando desde solicitud de urgencia',
                  subtitle:
                      'Se usara tipo urgencia. Solo se bloquean fechas pasadas; los conflictos se confirman manualmente.',
                  color: OcgColors.error,
                ),
                const SizedBox(height: 12),
              ],
              // ── Buscador de paciente ───────────────────────────────────
              TextField(
                controller: _searchCtrl,
                readOnly: _isUrgencyBooking,
                decoration: InputDecoration(
                  labelText: 'Buscar paciente',
                  prefixIcon: const Icon(Icons.person_search),
                  suffixIcon: _selectedPatient != null && !_isUrgencyBooking
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Cambiar paciente',
                          onPressed: () => setState(_clearSelectedPatient),
                        )
                      : null,
                ),
                onChanged: _isUrgencyBooking
                    ? null
                    : (_) => setState(() {
                        _selectedPatient = null;
                        _selectedTreatmentId = null;
                        _errorMsg = null;
                      }),
              ),

              // ── Dropdown de resultados ─────────────────────────────────
              // ✅ Column en vez de ConstrainedBox + ListView — evita el
              //    conflicto de constraints que causaba el crash de layout.
              if (showDropdown) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: filtered.take(6).map((p) {
                            return ListTile(
                              dense: true,
                              leading: GestureDetector(
                                onTap: () {
                                  final url = (p.fotoUrl ?? '').trim();
                                  if (url.isNotEmpty) {
                                    OcgPhotoViewer.show(
                                      context,
                                      photoUrl: url,
                                      patientName: p.nombre,
                                    );
                                  }
                                },
                                child: _patientAvatar(p),
                              ),
                              title: Text(p.nombre),
                              subtitle: Text(
                                p.telefono,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setState(() => _selectPatient(p)),
                            );
                          }).toList(),
                        ),
                ),
              ],

              // ── Chip del paciente seleccionado ─────────────────────────
              if (_selectedPatient != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F1EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final url = (_selectedPatient!.fotoUrl ?? '').trim();
                          if (url.isNotEmpty) {
                            OcgPhotoViewer.show(
                              context,
                              photoUrl: url,
                              patientName: _selectedPatient!.nombre,
                            );
                          }
                        },
                        child: _patientAvatar(_selectedPatient!),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPatient!.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: OcgColors.espresso,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _selectedPatient!.telefono.isEmpty
                                  ? 'Sin teléfono registrado'
                                  : _selectedPatient!.telefono,
                              style: TextStyle(
                                color: OcgColors.ink.withOpacity(0.62),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cambiar paciente',
                        onPressed: () => setState(_clearSelectedPatient),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ],

              if (_selectedPatient != null && !_isUrgencyBooking) ...[
                const SizedBox(height: 10),
                _treatmentAssociationCard(
                  treatments: writableTreatments,
                  selectedTreatment: selectedTreatment,
                ),
              ],

              const SizedBox(height: 12),

              // ── Tipo de cita (derivado de la fase del tratamiento) ────
              if (effectiveType != null && _selectedPatient != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcgColors.bronze.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: OcgColors.bronze.withOpacity(0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de cita',
                              style: TextStyle(
                                fontSize: 11,
                                color: OcgColors.ink.withOpacity(0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              appointmentTypeLabel(effectiveType),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: OcgColors.espresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: OcgColors.bronze.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stageNames[effectiveStage] ?? effectiveStage.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: OcgColors.bronze,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcgColors.mist,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: OcgColors.ink.withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selecciona un paciente para ver el tipo de cita',
                          style: TextStyle(
                            fontSize: 12,
                            color: OcgColors.ink.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // ── Fecha y hora ───────────────────────────────────────────
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: OcgColors.espresso),
                title: const Text('Fecha y hora'),
                subtitle: Text(
                  appointmentFmtDateTime(_dateTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OcgColors.espresso,
                  ),
                ),
                trailing: const Icon(
                  Icons.edit_calendar,
                  color: OcgColors.bronze,
                ),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Horarios disponibles por jornada. Mañana arriba (08:00 a 11:30) y tarde abajo (14:00 en adelante). Puedes desplegar o recoger cada bloque.',
                  style: TextStyle(
                    fontSize: 12,
                    color: OcgColors.ink.withOpacity(0.65),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final sortedSlots = _slotsForCurrentDay(availability).toList()
                    ..sort((a, b) => a.start.compareTo(b.start));
                  final morningSlots = sortedSlots
                      .where((s) => s.start.hour < 12)
                      .toList();
                  final afternoonSlots = sortedSlots
                      .where((s) => s.start.hour >= 12)
                      .toList();

                  Widget slotChip(AppointmentTimeSlot slot) {
                    final isSelected = slot.start == _dateTime;
                    return ChoiceChip(
                      label: Text(
                        slot.label,
                        style: TextStyle(
                          color: slot.isAvailable
                              ? OcgColors.espresso
                              : Colors.grey.shade600,
                        ),
                      ),
                      selected: isSelected && slot.isAvailable,
                      disabledColor: Colors.grey.shade300,
                      selectedColor: OcgColors.sand,
                      avatar: slot.isAvailable
                          ? const Icon(Icons.check_circle_outline, size: 15)
                          : const Icon(Icons.block, size: 15),
                      onSelected: slot.isAvailable
                          ? (_) => setState(() {
                              _dateTime = slot.start;
                              _errorMsg = null;
                            })
                          : null,
                    );
                  }

                  Widget section({
                    required String title,
                    required bool expanded,
                    required VoidCallback onToggle,
                    required List<AppointmentTimeSlot> slots,
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
                            if (slots.isEmpty)
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
                                children: slots.map(slotChip).toList(),
                              ),
                          ],
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _slotAvailabilitySummary(sortedSlots),
                      const SizedBox(height: 8),
                      _slotLegend(),
                      const SizedBox(height: 8),
                      section(
                        title: 'Mañana (08:00 - 11:30)',
                        expanded: _expandMorning,
                        onToggle: () =>
                            setState(() => _expandMorning = !_expandMorning),
                        slots: morningSlots,
                      ),
                      section(
                        title: 'Tarde (14:00 - cierre)',
                        expanded: _expandAfternoon,
                        onToggle: () => setState(
                          () => _expandAfternoon = !_expandAfternoon,
                        ),
                        slots: afternoonSlots,
                      ),
                    ],
                  );
                },
              ),

              // ── Duración ───────────────────────────────────────────────
              //No va a llevar duracion porque cada cita puede durar en promedio 30 a 45 minutos.

              // ── Notas ──────────────────────────────────────────────────
              TextField(
                controller: _notesCtrl,

                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),

              // ── Error ──────────────────────────────────────────────────
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMsg!,
                  style: const TextStyle(color: OcgColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => popDialog(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: OcgColors.bronze,
            foregroundColor: OcgColors.ivory,
          ),
          onPressed: _saving ? null : () => _submit(selectedTreatment),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OcgColors.ivory,
                  ),
                )
              : const Text('Crear cita'),
        ),
      ],
    );
  }
}

// ─── _AdminAppointmentsScreenState ───────────────────────────────────────────

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  AgendaInnerTab _innerTab = AgendaInnerTab.hoy;
  final bool _showTimeGrid =
      false; // Toggle entre vista lista y grilla de tiempo
  DateTime _monthCursor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime? _selectedMonthDay;
  AgendaFilter _historyFilter = AgendaFilter.activas;
  AgendaDayQuickFilter _dayQuickFilter = AgendaDayQuickFilter.dia;
  AgendaIncidenceSubFilter _incidenceSubFilter = AgendaIncidenceSubFilter.todas;
  AgendaSummaryFilter _daySummaryFilter = AgendaSummaryFilter.total;
  int _historyPage = 1;
  String? _focusedAppointmentId;
  String? _handledAgendaTarget;

  void _handleAgendaTargetFromQuery(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final appointmentId = uri.queryParameters['appointmentId']?.trim();
    final dateRaw = uri.queryParameters['date']?.trim();
    final targetToken = '$appointmentId|$dateRaw';

    if ((appointmentId == null || appointmentId.isEmpty) &&
        (dateRaw == null || dateRaw.isEmpty)) {
      if (_handledAgendaTarget != null || _focusedAppointmentId != null) {
        _handledAgendaTarget = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _focusedAppointmentId = null);
        });
      }
      return;
    }
    if (_handledAgendaTarget == targetToken) return;
    _handledAgendaTarget = targetToken;

    final parsedDate = dateRaw == null || dateRaw.isEmpty
        ? null
        : DateTime.tryParse(dateRaw);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (parsedDate != null) {
        ref
            .read(selectedAppointmentsDateProvider.notifier)
            .setDate(
              DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
            );
      }
      setState(() {
        _innerTab = AgendaInnerTab.hoy;
        _dayQuickFilter = AgendaDayQuickFilter.dia;
        _incidenceSubFilter = AgendaIncidenceSubFilter.todas;
        _daySummaryFilter = AgendaSummaryFilter.total;
        if (parsedDate != null) {
          _monthCursor = DateTime(parsedDate.year, parsedDate.month, 1);
        }
        _focusedAppointmentId = appointmentId?.isEmpty == true
            ? null
            : appointmentId;
      });
    });
  }

  Future<void> _handleSignOut() async {
    final confirm = await OcgLogoutDialog.show(
      context,
      roleLabel: 'Administrador',
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

  Widget _miniLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.78),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: OcgColors.ink.withOpacity(0.68),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _openAppointmentDetail(
    BuildContext context,
    AppointmentModel a,
  ) async {
    final ui = appointmentStatusUi(a);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a.patientName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: ui.dot),
                  const SizedBox(width: 6),
                  Text(
                    '${a.fechaHora.day.toString().padLeft(2, '0')}/${a.fechaHora.month.toString().padLeft(2, '0')}/${a.fechaHora.year} ${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.medical_services, size: 16, color: ui.dot),
                  const SizedBox(width: 6),
                  Text(_tipoLabel(a.tipo)),
                ],
              ),
              if (a.notas != null && a.notas!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notas: ${a.notas}'),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ui.dot.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ui.label,
                  style: TextStyle(color: ui.dot, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showRescheduleDialog(a);
            },
            child: const Text('Reprogramar'),
          ),
        ],
      ),
    );
  }

  String _tipoLabel(AppointmentType t) => switch (t) {
    AppointmentType.valoracion => 'Valoración',
    AppointmentType.control => 'Control',
    AppointmentType.instalacion => 'Instalación',
    AppointmentType.urgencia => 'Urgencia',
    AppointmentType.alta => 'Alta',
  };

  Future<void> _showRescheduleDialog(AppointmentModel appt) async {
    DateTime newDateTime = appt.fechaHora;
    int newDuration = appt.duracionMinutos;
    bool expandMorning = true;
    bool expandAfternoon = true;
    final existingAppointments =
        ref.read(appointmentsProvider).asData?.value ??
        const <AppointmentModel>[];
    final notesCtrl = TextEditingController(text: appt.notas ?? '');

    AvailabilityDayModel? availabilityForCurrentDay() {
      return ref
          .read(availabilityByDayProvider(appointmentDayKey(newDateTime)))
          .asData
          ?.value;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Reprogramar cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(appointmentFmtDateTime(newDateTime)),
                  subtitle: const Text(
                    'Fecha (L-V 08:00-12:00 y 14:00-18:00 · Sáb 08:00-12:00)',
                  ),
                  trailing: const Icon(Icons.edit_calendar, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: newDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (d == null) return;

                    final slots = _visibleSlotsForDay(
                      day: d,
                      existingAppointments: existingAppointments,
                      durationMinutes: newDuration,
                      excludeAppointmentId: appt.id,
                      availability: ref
                          .read(availabilityByDayProvider(appointmentDayKey(d)))
                          .asData
                          ?.value,
                    );
                    final firstAvailable = slots
                        .where((s) => s.isAvailable)
                        .firstOrNull;

                    setDs(() {
                      newDateTime =
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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Horarios por jornada (secuenciales). Mañana arriba y tarde abajo. Puedes desplegar o recoger cada bloque.',
                    style: TextStyle(
                      fontSize: 12,
                      color: OcgColors.ink.withOpacity(0.65),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (_) {
                    final slots = _visibleSlotsForDay(
                      day: newDateTime,
                      existingAppointments: existingAppointments,
                      durationMinutes: newDuration,
                      excludeAppointmentId: appt.id,
                      availability: availabilityForCurrentDay(),
                    ).toList()..sort((a, b) => a.start.compareTo(b.start));

                    final morningSlots = slots
                        .where((s) => s.start.hour < 12)
                        .toList();
                    final afternoonSlots = slots
                        .where((s) => s.start.hour >= 12)
                        .toList();

                    Widget chip(AppointmentTimeSlot slot) {
                      final isSelected = slot.start == newDateTime;
                      return ChoiceChip(
                        label: Text(
                          slot.label,
                          style: TextStyle(
                            color: slot.isAvailable
                                ? OcgColors.espresso
                                : Colors.grey.shade600,
                          ),
                        ),
                        avatar: slot.isAvailable
                            ? const Icon(Icons.check_circle_outline, size: 15)
                            : const Icon(Icons.block, size: 15),
                        selected: isSelected && slot.isAvailable,
                        disabledColor: Colors.grey.shade300,
                        selectedColor: OcgColors.sand,
                        onSelected: slot.isAvailable
                            ? (_) => setDs(() => newDateTime = slot.start)
                            : null,
                      );
                    }

                    Widget section({
                      required String title,
                      required bool expanded,
                      required VoidCallback onToggle,
                      required List<AppointmentTimeSlot> sectionSlots,
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
                              if (sectionSlots.isEmpty)
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
                                  children: sectionSlots.map(chip).toList(),
                                ),
                            ],
                          ],
                        ),
                      );
                    }

                    final available = slots.where((s) => s.isAvailable).length;
                    final blocked = slots.length - available;
                    final selectedAvailable = slots.any(
                      (s) => s.start == newDateTime && s.isAvailable,
                    );
                    final summaryColor = selectedAvailable
                        ? const Color(0xFF2E7D32)
                        : OcgColors.error;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: summaryColor.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: summaryColor.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                selectedAvailable
                                    ? Icons.event_repeat_outlined
                                    : Icons.warning_amber_outlined,
                                size: 19,
                                color: summaryColor,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  selectedAvailable
                                      ? '$available disponibles · $blocked bloqueados. Nuevo horario listo: ${appointmentFmtDateTime(newDateTime)}.'
                                      : '$available disponibles · $blocked bloqueados. Elige un horario disponible para continuar.',
                                  style: TextStyle(
                                    color: OcgColors.ink.withOpacity(0.76),
                                    fontSize: 12,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _miniLegend(OcgColors.sand, 'Seleccionado'),
                            _miniLegend(const Color(0xFF7A8A20), 'Disponible'),
                            _miniLegend(Colors.grey.shade500, 'Bloqueado'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        section(
                          title: 'Mañana (08:00 - 11:30)',
                          expanded: expandMorning,
                          onToggle: () =>
                              setDs(() => expandMorning = !expandMorning),
                          sectionSlots: morningSlots,
                        ),
                        section(
                          title: 'Tarde (14:00 - cierre)',
                          expanded: expandAfternoon,
                          onToggle: () =>
                              setDs(() => expandAfternoon = !expandAfternoon),
                          sectionSlots: afternoonSlots,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: newDuration,
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m, child: Text('$m min')),
                      )
                      .toList(),
                  onChanged: (v) {
                    final nextDuration = v ?? 30;
                    final slots = _visibleSlotsForDay(
                      day: newDateTime,
                      existingAppointments: existingAppointments,
                      durationMinutes: nextDuration,
                      excludeAppointmentId: appt.id,
                      availability: availabilityForCurrentDay(),
                    );
                    final currentAvailable = slots.any(
                      (s) => s.start == newDateTime && s.isAvailable,
                    );
                    final firstAvailable = slots
                        .where((s) => s.isAvailable)
                        .firstOrNull;

                    setDs(() {
                      newDuration = nextDuration;
                      if (!currentAvailable && firstAvailable != null) {
                        newDateTime = firstAvailable.start;
                      }
                    });
                  },
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
              onPressed: () => popDialog(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.bronze,
                foregroundColor: OcgColors.ivory,
              ),
              onPressed: () async {
                final notPastError =
                    AppointmentsBusinessRules.validateStartNotInPast(
                      start: newDateTime,
                    );
                if (notPastError != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(notPastError)));
                  return;
                }

                final workingHoursError =
                    AppointmentsBusinessRules.validateWithinWorkingHours(
                      start: newDateTime,
                      durationMinutes: newDuration,
                    );
                if (workingHoursError != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(workingHoursError)));
                  return;
                }

                final hasConflict = AppointmentsBusinessRules.hasTimeConflict(
                  existingAppointments: existingAppointments,
                  newStart: newDateTime,
                  durationMinutes: newDuration,
                  excludeAppointmentId: appt.id,
                );
                if (hasConflict) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ese horario está ocupado o dentro del buffer de 10 min.',
                      ),
                    ),
                  );
                  return;
                }

                popDialog(ctx);
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
    ).then((_) => notesCtrl.dispose());
  }

  Future<void> _showCancelDialog(AppointmentModel appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Seguro que deseas cancelar la cita de '
          '${appt.patientName}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.error,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
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

  Future<void> _showNoShowDialog(AppointmentModel appt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar inasistencia'),
        content: Text(
          '¿Confirmas que ${appt.patientName} no asistió a esta cita?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, no asistió'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, AppointmentStatus.noAsistio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita marcada como no asistida.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo marcar inasistencia: $e')),
      );
    }
  }

  Future<void> _onReabrirCompletada(AppointmentModel appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir cita'),
        content: Text(
          'La cita de ${appt.patientName} volverá a estado confirmada. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OcgColors.espresso,
              foregroundColor: OcgColors.ivory,
            ),
            onPressed: () => popDialog(ctx, true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, AppointmentStatus.confirmada);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cita reabierta.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo reabrir la cita: $e')));
    }
  }

  /// ✅ NUEVO: navegar a la pantalla de consultación clínica
  /// en vez de completar la cita directamente.
  // ignore: unused_element
  Future<void> _onCompletarCitaConDictamen(AppointmentModel appt) async {
    if (!mounted) return;
    context.push(RouteNames.adminConsultation, extra: appt);
  }

  // ignore: unused_element
  Future<Map<String, dynamic>?> _showValoracionDictamenDialog({
    required String patientName,
  }) async {
    TreatmentType? selected;
    DateTime? fechaProximoPago;
    final notaCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    bool montoValido(String value) {
      final v = double.tryParse(value.replaceAll(',', '.').trim());
      return v != null && v > 0;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final montoOk = montoValido(montoCtrl.text);
          return AlertDialog(
            title: const Text('Dictamen de valoración inicial'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paciente: $patientName'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TreatmentType>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de tratamiento (obligatorio)',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: TreatmentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(appointmentTypeLabelTratamiento(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => selected = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setSt(() {}),
                    decoration: InputDecoration(
                      labelText: 'Valor total del tratamiento (obligatorio)',
                      prefixText: r'$ ',
                      errorText: montoCtrl.text.isEmpty || montoOk
                          ? null
                          : 'Ingresa un monto válido mayor a cero',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fechaProximoPago == null
                              ? 'Próximo pago: no definido'
                              : 'Próximo pago: ${appointmentFmtDate(fechaProximoPago!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (picked != null) {
                            setSt(() => fechaProximoPago = picked);
                          }
                        },
                        child: const Text('Definir fecha'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notaCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nota clínica inicial (opcional)',
                      hintText: 'Resumen del diagnóstico y plan inicial',
                    ),
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
                onPressed: (selected == null || !montoOk)
                    ? null
                    : () => popDialog(ctx, {
                        'tipoTratamiento': selected,
                        'totalTratamiento': double.parse(
                          montoCtrl.text.replaceAll(',', '.').trim(),
                        ),
                        'fechaProximoPago': fechaProximoPago,
                        'nota': notaCtrl.text,
                      }),
                child: const Text('Guardar y completar'),
              ),
            ],
          );
        },
      ),
    );

    notaCtrl.dispose();
    montoCtrl.dispose();
    return result;
  }

  String appointmentTypeLabelTratamiento(TreatmentType type) {
    switch (type) {
      case TreatmentType.convencional:
        return 'Convencional';
      case TreatmentType.estetico:
        return 'Estético';
      case TreatmentType.autoligado:
        return 'Autoligado';
      case TreatmentType.alineadores:
        return 'Alineadores';
      case TreatmentType.ortopedia:
        return 'Ortopedia';
      case TreatmentType.interceptivo:
        return 'Interceptivo';
      case TreatmentType.retenedores:
        return 'Retenedores';
    }
  }

  Widget _buildInnerTabs({bool premium = true}) {
    void selectTab(AgendaInnerTab tab) {
      setState(() {
        _innerTab = tab;
        if (tab == AgendaInnerTab.mes) {
          final now = DateTime.now();
          _monthCursor = DateTime(now.year, now.month, 1);
          _selectedMonthDay = DateTime(now.year, now.month, now.day);
        }
      });
    }

    if (!premium) {
      Widget item(AgendaInnerTab tab, String label) {
        final active = _innerTab == tab;
        return TextButton(
          onPressed: () => selectTab(tab),
          style: TextButton.styleFrom(
            foregroundColor: active ? OcgColors.espresso : OcgColors.ink,
            textStyle: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 2,
                width: 36,
                decoration: BoxDecoration(
                  color: active ? OcgColors.espresso : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: OcgColors.bronze.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            item(AgendaInnerTab.hoy, 'Hoy'),
            item(AgendaInnerTab.semana, 'Semana'),
            item(AgendaInnerTab.mes, 'Mes'),
            item(AgendaInnerTab.historial, 'Historial'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: OcgSegmentedTabs<AgendaInnerTab>(
        selectedValue: _innerTab,
        onChanged: selectTab,
        compact: true,
        items: const [
          OcgSegmentedTabItem(
            value: AgendaInnerTab.hoy,
            label: 'Hoy',
            icon: Icons.today_outlined,
          ),
          OcgSegmentedTabItem(
            value: AgendaInnerTab.semana,
            label: 'Semana',
            icon: Icons.view_week_outlined,
          ),
          OcgSegmentedTabItem(
            value: AgendaInnerTab.mes,
            label: 'Mes',
            icon: Icons.calendar_view_month_outlined,
          ),
          OcgSegmentedTabItem(
            value: AgendaInnerTab.historial,
            label: 'Historial',
            icon: Icons.history_outlined,
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusAction(AppointmentModel a, String action) async {
    switch (action) {
      case 'confirmar':
        await ref
            .read(appointmentsRepositoryProvider)
            .updateAppointmentStatus(a.id, AppointmentStatus.confirmada);
        break;
      case 'completar':
        await ref
            .read(appointmentsRepositoryProvider)
            .updateAppointmentStatus(a.id, AppointmentStatus.completada);
        break;
      case 'dictamen':
        if (!mounted) return;
        context.push(RouteNames.adminConsultation, extra: a);
        break;
      case 'reprogramar':
        await _showRescheduleDialog(a);
        break;
      case 'cancelar':
        await _showCancelDialog(a);
        break;
      case 'no_asistio':
        await _showNoShowDialog(a);
        break;
      case 'reabrir':
        await _onReabrirCompletada(a);
        break;
    }
  }

  void _openPatientProfile(String patientId) {
    if (patientId.trim().isEmpty) return;
    context.go(
      RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId),
    );
  }

  List<AppointmentTimeSlot> _visibleSlotsForDay({
    required DateTime day,
    required int durationMinutes,
    required List<AppointmentModel> existingAppointments,
    String? excludeAppointmentId,
    AvailabilityDayModel? availability,
  }) {
    final slots = AppointmentsBusinessRules.buildDailySlots(
      day: day,
      existingAppointments: existingAppointments,
      durationMinutes: durationMinutes,
      excludeAppointmentId: excludeAppointmentId,
      stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
    );

    final now = DateTime.now();
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);

    return slots.where((slot) {
      if (normalizedDay == today && !slot.start.isAfter(now)) return false;
      if (availability != null && !availability.isSlotAvailable(slot.label)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _actionRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Acciones de acceso rápido (botones visibles fuera del popup)
  List<Widget> _buildQuickActions(AppointmentModel a) {
    final quick = <Widget>[];

    // Dictamen — siempre visible
    quick.add(
      _quickActionBtn(
        icon: Icons.description_outlined,
        label: 'Dictamen',
        color: OcgColors.bronze,
        onTap: () => _handleStatusAction(a, 'dictamen'),
      ),
    );

    // Confirmar o Completar según estado
    if (a.estado == AppointmentStatus.programada) {
      quick.add(
        _quickActionBtn(
          icon: Icons.check_circle_outline,
          label: 'Confirmar',
          color: const Color(0xFF1565C0),
          onTap: () => _handleStatusAction(a, 'confirmar'),
        ),
      );
    } else if (a.estado == AppointmentStatus.confirmada) {
      quick.add(
        _quickActionBtn(
          icon: Icons.done_all,
          label: 'Completar',
          color: const Color(0xFF2E7D32),
          onTap: () => _handleStatusAction(a, 'completar'),
        ),
      );
    }

    return quick;
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Acciones secundarias (dentro del popup)
  List<PopupMenuEntry<_AppointmentAction>> _buildSecondaryMenuItems(
    AppointmentModel a,
  ) {
    final items = <PopupMenuEntry<_AppointmentAction>>[];

    items.add(
      PopupMenuItem<_AppointmentAction>(
        value: _AppointmentAction(
          label: 'Perfil del paciente',
          icon: Icons.person_outline,
          onTap: () => _openPatientProfile(a.patientId),
        ),
        height: 42,
        child: _actionRow(
          Icons.person_outline,
          'Perfil del paciente',
          OcgColors.espresso,
        ),
      ),
    );

    void addDivider() => items.add(const PopupMenuDivider(height: 1));
    void addAction({
      required IconData icon,
      required String label,
      Color? color,
      required VoidCallback onTap,
    }) {
      items.add(
        PopupMenuItem<_AppointmentAction>(
          value: _AppointmentAction(
            label: label,
            icon: icon,
            color: color,
            onTap: onTap,
          ),
          height: 42,
          child: _actionRow(icon, label, color ?? OcgColors.espresso),
        ),
      );
    }

    if (a.estado == AppointmentStatus.programada ||
        a.estado == AppointmentStatus.confirmada) {
      addDivider();
      addAction(
        icon: Icons.edit_calendar_outlined,
        label: 'Reprogramar',
        color: OcgColors.bronze,
        onTap: () => _handleStatusAction(a, 'reprogramar'),
      );
      addAction(
        icon: Icons.person_off_outlined,
        label: 'No asistió',
        color: const Color(0xFFC56B16),
        onTap: () => _handleStatusAction(a, 'no_asistio'),
      );
      addAction(
        icon: Icons.cancel_outlined,
        label: 'Cancelar cita',
        color: OcgColors.error,
        onTap: () => _handleStatusAction(a, 'cancelar'),
      );
    }

    if (a.estado == AppointmentStatus.completada) {
      addDivider();
      addAction(
        icon: Icons.lock_open_outlined,
        label: 'Reabrir cita',
        color: const Color(0xFF1565C0),
        onTap: () => _handleStatusAction(a, 'reabrir'),
      );
    }

    return items;
  }

  Widget _buildAppointmentActionsInline(AppointmentModel a) {
    final quickActions = _buildQuickActions(a);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [...quickActions],
    );
  }

  Widget _agendaPill({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaAppointmentCard(
    AppointmentModel a, {
    bool showDate = true,
    bool dense = false,
    bool highlighted = false,
  }) {
    final ui = appointmentStatusUi(a);
    final timeLabel = showDate
        ? '${a.fechaHora.day.toString().padLeft(2, '0')}/${a.fechaHora.month.toString().padLeft(2, '0')} · ${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}'
        : '${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}';
    final autoLabel = autoScheduleLabel(a);

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 8 : 10),
      padding: EdgeInsets.only(
        top: dense ? 12 : 14,
        left: dense ? 12 : 14,
        bottom: dense ? 12 : 14,
        right: dense ? 46 : 48, // espacio para el botón ⋮ fijo a la derecha
      ),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(dense ? 18 : 22),
        border: Border.all(
          color: highlighted ? OcgColors.espresso : ui.line.withOpacity(0.24),
          width: highlighted ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? OcgColors.espresso.withOpacity(0.16)
                : OcgColors.espresso.withOpacity(0.055),
            blurRadius: highlighted ? 24 : 16,
            offset: Offset(0, highlighted ? 12 : 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlighted) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A3527), Color(0xFFB07D3C)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.center_focus_strong_outlined,
                        size: 14,
                        color: OcgColors.ivory,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cita seleccionada desde el paciente',
                        style: TextStyle(
                          color: OcgColors.ivory,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ui.line.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(agendaStatusIcon(a), color: ui.line, size: 21),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$timeLabel · ${appointmentTypeLabel(a.tipo)} · ${a.duracionMinutos} min',
                          style: TextStyle(
                            color: OcgColors.ink.withOpacity(0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _agendaPill(
                    label: ui.label,
                    color: ui.line,
                    icon: agendaStatusIcon(a),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Pills deslizables horizontalmente en móvil
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _agendaPill(
                      label: agendaOperationalHint(a),
                      color: isAgendaIncident(a)
                          ? OcgColors.error
                          : OcgColors.bronze,
                      icon: isAgendaIncident(a)
                          ? Icons.warning_amber_outlined
                          : Icons.tips_and_updates_outlined,
                    ),
                    if (a.stageName != null)
                      _agendaPill(
                        label: a.stageName!,
                        color: OcgColors.bronze,
                        icon: Icons.timeline_outlined,
                      ),
                    if (autoLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: autoScheduleBg(a),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          autoLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: autoScheduleFg(a),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if ((a.notas ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F1EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Notas clínicas: ${a.notas!.trim()}',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: OcgColors.ink.withOpacity(0.78),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _buildAppointmentActionsInline(a),
            ],
          ),
          // ── Botón ⋮ fijo en esquina inferior derecha ──
          Positioned(
            right: 0,
            bottom: 0,
            child: PopupMenuButton<_AppointmentAction>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Más acciones',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              itemBuilder: (context) => _buildSecondaryMenuItems(a),
              onSelected: (action) => action.onTap(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agendaEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onPrimary,
    String primaryLabel = 'Nueva cita',
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F5EF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: OcgColors.espresso, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OcgColors.espresso,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OcgColors.bronze, height: 1.3),
            ),
            if (onPrimary != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(primaryLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: OcgColors.espresso,
                  foregroundColor: OcgColors.ivory,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    final next = DateTime(_monthCursor.year, _monthCursor.month + delta, 1);
    setState(() {
      _monthCursor = next;
      _selectedMonthDay = null;
    });
  }

  Widget _historyFilterItem(String label, AgendaFilter filter, int count) {
    final active = _historyFilter == filter;
    return InkWell(
      onTap: () => setState(() {
        _historyFilter = filter;
        _historyPage = 1;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? OcgColors.espresso : OcgColors.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active ? OcgColors.espresso : OcgColors.mist,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: active ? OcgColors.ivory : OcgColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryAgenda(
    BuildContext context,
    List<AppointmentModel> appointments,
  ) {
    final items = historyItemsForAgenda(
      appointments,
      filter: _historyFilter,
      page: _historyPage,
    );
    final totalFiltered = historyCountByFilter(appointments, _historyFilter);
    final hasMore = items.length < totalFiltered;

    final groups = <String, List<AppointmentModel>>{};
    for (final item in items) {
      final key =
          '${item.fechaHora.year}-${item.fechaHora.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final historyChildren = sortedKeys.isEmpty
        ? <Widget>[
            _agendaEmptyState(
              title: 'Sin historial para este filtro',
              subtitle:
                  'Cambia el filtro o revisa otra seccion para encontrar citas cerradas.',
              icon: Icons.history_toggle_off_outlined,
            ),
          ]
        : <Widget>[
            for (final key in sortedKeys) ...[
              Builder(
                builder: (_) {
                  final sample = groups[key]!.first.fechaHora;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      agendaMonthLabel(
                        DateTime(sample.year, sample.month, 1),
                      ).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OcgColors.ink.withOpacity(0.6),
                      ),
                    ),
                  );
                },
              ),
              ...groups[key]!.map(
                (a) =>
                    _buildAgendaAppointmentCard(a, showDate: true, dense: true),
              ),
            ],
            if (hasMore)
              InkWell(
                onTap: () => setState(() => _historyPage += 1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: OcgColors.bronze.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'Cargar mas...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: OcgColors.ink.withOpacity(0.8)),
                  ),
                ),
              ),
          ];

    final filtersPanel = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9E4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar por estado',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _historyFilterItem(
            'Todas',
            AgendaFilter.activas,
            historyCountByFilter(appointments, AgendaFilter.activas),
          ),
          _historyFilterItem(
            'Completadas',
            AgendaFilter.completadas,
            historyCountByFilter(appointments, AgendaFilter.completadas),
          ),
          _historyFilterItem(
            'Perdidas',
            AgendaFilter.perdidas,
            historyCountByFilter(appointments, AgendaFilter.perdidas),
          ),
          _historyFilterItem(
            'Canceladas',
            AgendaFilter.canceladas,
            historyCountByFilter(appointments, AgendaFilter.canceladas),
          ),
          _historyFilterItem(
            'Incidencias',
            AgendaFilter.incidencias,
            historyCountByFilter(appointments, AgendaFilter.incidencias),
          ),
        ],
      ),
    );

    final isDesktop = WebLayoutContext.useDesktopShell(context);
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(right: 6),
              children: historyChildren,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: filtersPanel),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: filtersPanel,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: historyChildren,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _handleAgendaTargetFromQuery(context);
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final loadedAppointments =
        appointmentsAsync.asData?.value ?? const <AppointmentModel>[];

    // Calendario del mes: SIEMPRE visible como sidebar/hero
    final persistentCalendar = MonthCalendarWidget(
      monthCursor: _monthCursor,
      selectedDay: _selectedMonthDay,
      appointments: loadedAppointments,
      onMonthChange: (delta) => setState(() => _changeMonth(delta)),
      onDayTap: (day, dayItems) {
        setState(() {
          _selectedMonthDay = day;
          ref.read(selectedAppointmentsDateProvider.notifier).setDate(day);
        });
      },
    );

    // Hoy: TimeGrid día
    final hoyAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => TimeGridView(
        appointments: appointments,
        selectedDate: selectedDate,
        showWeek: false,
        onTapAppointment: (a) => _openAppointmentDetail(context, a),
        onTapSlot: (slotTime) => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: slotTime,
          existingAppointments: appointments,
        ),
      ),
    );

    // Semana: TimeGrid semanal
    final semanaAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => TimeGridView(
        appointments: appointments,
        selectedDate: selectedDate,
        showWeek: true,
        onTapAppointment: (a) => _openAppointmentDetail(context, a),
        onTapSlot: (slotTime) => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: slotTime,
          existingAppointments: appointments,
        ),
      ),
    );

    // Mes: Lista de citas del día seleccionado en el calendario
    final mesAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) {
        final selectedDay = _selectedMonthDay;
        if (selectedDay == null) {
          return _agendaEmptyState(
            title: 'Selecciona un día',
            subtitle:
                'Toca una fecha del calendario para ver las citas de ese día.',
            icon: Icons.calendar_month_outlined,
          );
        }
        final dayItems = appointmentsForDay(appointments, selectedDay);
        if (dayItems.isEmpty) {
          return _agendaEmptyState(
            title: 'Sin citas este día',
            subtitle:
                'No hay citas programadas para ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}.',
            icon: Icons.event_available_outlined,
            onPrimary: () => AdminAppointmentsScreen.showCreateDialog(
              context,
              ref,
              baseDate: selectedDay,
              existingAppointments: appointments,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: dayItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _buildAgendaAppointmentCard(dayItems[index], dense: true),
        );
      },
    );

    final historialAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildHistoryAgenda(context, appointments),
    );

    final agendaBody = switch (_innerTab) {
      AgendaInnerTab.hoy => hoyAgendaBody,
      AgendaInnerTab.semana => semanaAgendaBody,
      AgendaInnerTab.mes => mesAgendaBody,
      AgendaInnerTab.historial => historialAgendaBody,
    };

    final subtitleByTab = switch (_innerTab) {
      AgendaInnerTab.hoy => 'Seguimiento diario con timeline y resumen',
      AgendaInnerTab.semana => 'Vista semanal con slots de 30 minutos',
      AgendaInnerTab.mes => 'Vista mensual con detalle por día',
      AgendaInnerTab.historial => 'Historial por estado y mes',
    };

    final panelTitleByTab = switch (_innerTab) {
      AgendaInnerTab.hoy => 'Hoy',
      AgendaInnerTab.semana => 'Semana',
      AgendaInnerTab.mes => 'Mes',
      AgendaInnerTab.historial => 'Historial',
    };

    final mobileContent = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: persistentCalendar),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildInnerTabs()),
        ];
      },
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(key: ValueKey(_innerTab), child: agendaBody),
      ),
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      final desktopContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Agenda clínica',
            subtitle: subtitleByTab,
            trailing: ActionToolbar(
              actions: [
                OutlinedButton.icon(
                  onPressed: () =>
                      AdminAppointmentsScreen.showCreatePatientAccountDialog(
                        context,
                        ref,
                      ),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Crear cuenta paciente'),
                ),
                FilledButton.icon(
                  onPressed: () => AdminAppointmentsScreen.showCreateDialog(
                    context,
                    ref,
                    baseDate: selectedDate,
                    existingAppointments:
                        appointmentsAsync.asData?.value ?? const [],
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva cita'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 720,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar: Calendario del mes (siempre visible)
                SizedBox(width: 300, child: persistentCalendar),
                const SizedBox(width: 12),
                // Contenido principal
                Expanded(
                  child: SectionPanel(
                    title: panelTitleByTab,
                    expandChild: true,
                    trailing: ActionToolbar(
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(selectedAppointmentsDateProvider.notifier)
                              .setDate(selectedDate),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar vista'),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInnerTabs(premium: false),
                        const SizedBox(height: 8),
                        Expanded(child: agendaBody),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      return AdminWebShell(title: 'Agenda', child: desktopContent);
    }

    if (widget.embeddedInMobileShell) {
      return mobileContent;
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 2,
      title: 'Agenda de citas',
      appBarActions: const [],
      onSignOut: _handleSignOut,
      railTrailing: OutlinedButton.icon(
        onPressed: _handleSignOut,
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
      body: mobileContent,
      floatingActionButton: FloatingActionButton(
        mini: true,
        tooltip: 'Nueva cita',
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: selectedDate,
          existingAppointments: appointmentsAsync.asData?.value ?? const [],
        ),
        child: const Icon(Icons.add, size: 18),
      ),
    );
  }
}

// ─── AppointmentCard ──────────────────────────────────────────────────────────

class _AppointmentReminderSummary extends ConsumerWidget {
  const _AppointmentReminderSummary({required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(
      appointmentRemindersProvider(appointmentId),
    );

    return remindersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        Color colorFor(String status) {
          switch (status) {
            case 'sent':
              return const Color(0xFF2E7D32);
            case 'pending':
              return const Color(0xFF1565C0);
            case 'pending_provider':
              return const Color(0xFFBA7517);
            case 'failed':
              return OcgColors.error;
            case 'cancelled':
            case 'obsolete':
            case 'skipped':
              return OcgColors.ink;
            default:
              return OcgColors.ink;
          }
        }

        String labelFor(String kind) {
          switch (kind) {
            case 'day_before':
              return '24h';
            case 'hour_before':
              return '1h';
            default:
              return kind;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recordatorios',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OcgColors.espresso,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorFor(item.status).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorFor(item.status).withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '${item.channel} ${labelFor(item.kind)} · ${item.status}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorFor(item.status),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onConfirmar,
    this.onCompletar,
    this.onReprogramar,
    this.onCancelar,
    this.onReabrirCompletada,
    this.onNoCompletada,
    this.onDictamen,
    this.onOpenInAgenda,
    this.showReminders = true,
  });

  final AppointmentModel appointment;
  final Future<void> Function()? onConfirmar;
  final Future<void> Function()? onCompletar;
  final VoidCallback? onReprogramar;
  final VoidCallback? onCancelar;
  final Future<void> Function()? onReabrirCompletada;
  final Future<void> Function()? onNoCompletada;
  final VoidCallback? onDictamen;
  final VoidCallback? onOpenInAgenda;
  final bool showReminders;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = switch (appointment.estado) {
      AppointmentStatus.programada => const Color(0xFFBA7517),
      AppointmentStatus.confirmada => const Color(0xFF1565C0),
      AppointmentStatus.completada => const Color(0xFF2E7D32),
      AppointmentStatus.cancelada => OcgColors.error,
      AppointmentStatus.noAsistio => OcgColors.error,
      AppointmentStatus.reprogramada => const Color(0xFF7E3AF2),
    };

    final String statusLabel = switch (appointment.estado) {
      AppointmentStatus.programada => 'Activa',
      AppointmentStatus.confirmada => 'Confirmada',
      AppointmentStatus.completada => 'Completada',
      AppointmentStatus.cancelada => 'Cancelada',
      AppointmentStatus.noAsistio => 'No asistió',
      AppointmentStatus.reprogramada => 'Reprogramada',
    };
    final isUrgency = appointment.tipo == AppointmentType.urgencia;
    final cardRadius = BorderRadius.circular(isUrgency ? 8 : 14);
    final borderColor = isUrgency
        ? OcgColors.error.withOpacity(0.38)
        : statusColor.withOpacity(0.25);

    return Card(
      elevation: isUrgency ? 3 : 1,
      color: isUrgency ? const Color(0xFFFFFCF8) : null,
      shadowColor: isUrgency
          ? OcgColors.error.withOpacity(0.18)
          : OcgColors.espresso.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: borderColor, width: isUrgency ? 1.2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ─────────────────────────────────────────────────
            if (isUrgency)
              _UrgentAppointmentHeader(
                appointment: appointment,
                statusColor: statusColor,
                statusLabel: statusLabel,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _AppointmentStatusChip(
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (isUrgency)
              _UrgentAppointmentMeta(appointment: appointment)
            else
              Text(
                '${appointmentTypeLabel(appointment.tipo)} · '
                '${appointmentFmtDateTime(appointment.fechaHora)} · '
                '${appointment.duracionMinutos} min',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (appointment.notas != null && appointment.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isUrgency ? 10 : 0,
                  vertical: isUrgency ? 8 : 0,
                ),
                decoration: BoxDecoration(
                  color: isUrgency
                      ? const Color(0xFFFFF4F2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isUrgency
                      ? Border.all(color: OcgColors.error.withOpacity(0.14))
                      : null,
                ),
                child: Text(
                  appointment.notas!,
                  style: TextStyle(
                    fontSize: isUrgency ? 12 : 11,
                    color: isUrgency
                        ? OcgColors.espresso.withOpacity(0.72)
                        : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                  ),
                ),
              ),
            ],
            if (appointment.stageName != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: OcgColors.bronze.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      size: 12,
                      color: OcgColors.bronze,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fase: ${appointment.stageName}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: OcgColors.bronze,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showReminders) ...[
              const SizedBox(height: 10),
              _AppointmentReminderSummary(appointmentId: appointment.id),
            ],

            if (onOpenInAgenda != null) ...[
              const SizedBox(height: 12),
              _OpenInAgendaButton(onPressed: onOpenInAgenda!),
            ],

            // ── Acciones ─────────────────────────────────────────────────
            if (onDictamen != null ||
                onConfirmar != null ||
                onCompletar != null ||
                onReprogramar != null ||
                onCancelar != null ||
                onReabrirCompletada != null ||
                onNoCompletada != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (onDictamen != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 14),
                      label: const Text('Dictamen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OcgColors.bronze,
                        side: BorderSide(
                          color: OcgColors.bronze.withOpacity(0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onDictamen,
                    ),
                  if (onConfirmar != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Confirmar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onConfirmar,
                    ),
                  if (onCompletar != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.done_all, size: 14),
                      label: const Text('Completar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onCompletar,
                    ),
                  if (onReprogramar != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_calendar, size: 14),
                      label: const Text('Reprogramar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OcgColors.bronze,
                        side: const BorderSide(color: OcgColors.bronze),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onReprogramar,
                    ),
                  if (onCancelar != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OcgColors.error,
                        side: const BorderSide(color: OcgColors.error),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancelar cita'),
                            content: const Text(
                              '¿Confirmas cancelar esta cita?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('No'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Sí, cancelar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) onCancelar?.call();
                      },
                    ),
                  if (onReabrirCompletada != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open_outlined, size: 14),
                      label: const Text('Reabrir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onReabrirCompletada,
                    ),
                  if (onNoCompletada != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_off_outlined, size: 14),
                      label: const Text('No asistió'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade800),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Marcar inasistencia'),
                            content: const Text(
                              '¿Confirmas marcar esta cita como no asistida?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('No'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Sí, marcar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await onNoCompletada?.call();
                      },
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

class _UrgentAppointmentHeader extends StatelessWidget {
  const _UrgentAppointmentHeader({
    required this.appointment,
    required this.statusColor,
    required this.statusLabel,
  });

  final AppointmentModel appointment;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: OcgColors.espresso,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            color: Color(0xFFFFE7E7),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Urgencia OCG',
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appointment.patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OcgColors.espresso.withOpacity(0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _AppointmentStatusChip(label: statusLabel, color: statusColor),
      ],
    );
  }
}

class _UrgentAppointmentMeta extends StatelessWidget {
  const _UrgentAppointmentMeta({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OcgColors.sand.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 17,
            color: OcgColors.espresso.withOpacity(0.72),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appointmentFmtDateTime(appointment.fechaHora),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OcgColors.espresso,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: OcgColors.sand),
            ),
            child: Text(
              '${appointment.duracionMinutos} min',
              style: const TextStyle(
                color: OcgColors.bronze,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentStatusChip extends StatelessWidget {
  const _AppointmentStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OpenInAgendaButton extends StatelessWidget {
  const _OpenInAgendaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF4A3527), Color(0xFF8C6239)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: OcgColors.ivory,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ver cita en agenda',
                    style: TextStyle(
                      color: OcgColors.ivory,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: OcgColors.ivory,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action item for the appointment popup menu
class _AppointmentAction {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _AppointmentAction({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });
}
