import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/data/models/availability_day_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/providers/availability_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
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
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateApptDialog(
        baseDate: baseDate,
        preselectedPatient: preselectedPatient,
        existingAppointments: existingAppointments,
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
  });

  final WidgetRef callerRef;
  final List<AppointmentModel> existingAppointments;
  final DateTime? baseDate;
  final PatientModel? preselectedPatient;

  @override
  ConsumerState<_CreateApptDialog> createState() => _CreateApptDialogState();
}

class _CreateApptDialogState extends ConsumerState<_CreateApptDialog> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _notesCtrl;

  PatientModel? _selectedPatient;
  AppointmentType? _type; // derivado de la fase del paciente
  final int _durationMinutes = 30;
  late DateTime _dateTime;
  bool _saving = false;
  bool _expandMorning = true;
  bool _expandAfternoon = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final seed = widget.baseDate ?? DateTime.now();
    _dateTime = DateTime(seed.year, seed.month, seed.day, 10, 0);
    _selectedPatient = widget.preselectedPatient;
    _type = _selectedPatient != null
        ? AppointmentsBusinessRules.appointmentTypeForStage(
            _selectedPatient!.etapaActual,
          )
        : null;
    _searchCtrl = TextEditingController(
      text: widget.preselectedPatient?.nombre ?? '',
    );
    _notesCtrl = TextEditingController();
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

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (d == null) return;

    setState(() {
      _dateTime = DateTime(
        d.year,
        d.month,
        d.day,
        AppointmentsBusinessRules.workdayStartHour,
        0,
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

  Future<void> _submit() async {
    if (_selectedPatient == null) {
      setState(() => _errorMsg = 'Selecciona un paciente de la lista.');
      return;
    }
    if (_type == null) {
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

    final workingHoursError =
        AppointmentsBusinessRules.validateWithinWorkingHours(
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
    if (hasConflict) {
      setState(
        () => _errorMsg =
            'Ese horario está ocupado o dentro del buffer de 10 min.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });
    final notasTexto = _notesCtrl.text.trim();
    try {
      await widget.callerRef
          .read(appointmentsRepositoryProvider)
          .createAppointment(
            AppointmentModel(
              id: '',
              patientId: _selectedPatient!.id,
              patientName: _selectedPatient!.nombre,
              patientPhone: _selectedPatient!.telefono,
              creadoPor: 'admin',
              tipo: _type!,
              estado: AppointmentStatus.programada,
              fechaHora: _dateTime,
              duracionMinutos: _durationMinutes,
              notas: notasTexto.isEmpty ? null : notasTexto,
              stageId: _selectedPatient!.etapaActual,
            ),
          );
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
      child: Icon(
        Icons.person,
        size: 17,
        color: OcgColors.ivory,
      ),
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
      title: const Text('Nueva cita'),
      content: SizedBox(
        // ✅ Ancho fijo evita que IntrinsicWidth falle con el dropdown
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Buscador de paciente ───────────────────────────────────
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar paciente',
                  prefixIcon: const Icon(Icons.person_search),
                  suffixIcon: _selectedPatient != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Cambiar paciente',
                          onPressed: () => setState(() {
                            _selectedPatient = null;
                            _searchCtrl.clear();
                          }),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {
                  _selectedPatient = null;
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
                              onTap: () => setState(() {
                                _selectedPatient = p;
                                _searchCtrl.text = p.nombre;
                                _type = AppointmentsBusinessRules.appointmentTypeForStage(
                                  p.etapaActual,
                                );
                                _errorMsg = null;
                              }),
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
                          final url =
                              (_selectedPatient!.fotoUrl ?? '').trim();
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
                        onPressed: () => setState(() {
                          _selectedPatient = null;
                          _searchCtrl.clear();
                        }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Tipo de cita (derivado de la fase del tratamiento) ────
              if (_type != null && _selectedPatient != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcgColors.bronze.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
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
                              appointmentTypeLabel(_type!),
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
                          stageNames[_selectedPatient!.etapaActual] ??
                              _selectedPatient!.etapaActual.name,
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
          onPressed: _saving ? null : _submit,
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
  DateTime _monthCursor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime? _selectedMonthDay;
  AgendaFilter _historyFilter = AgendaFilter.activas;
  AgendaDayQuickFilter _dayQuickFilter = AgendaDayQuickFilter.dia;
  AgendaIncidenceSubFilter _incidenceSubFilter = AgendaIncidenceSubFilter.todas;
  int _historyPage = 1;

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
  Future<void> _onCompletarCitaConDictamen(AppointmentModel appt) async {
    if (!mounted) return;
    context.push(
      RouteNames.adminConsultation,
      extra: appt,
    );
  }

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

  Widget _buildAppointmentActionsInline(AppointmentModel a) {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: () => _openPatientProfile(a.patientId),
        icon: const Icon(Icons.person_outline, size: 14),
        label: const Text('Perfil'),
        style: OutlinedButton.styleFrom(
          foregroundColor: OcgColors.espresso,
          side: BorderSide(color: OcgColors.espresso.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => _handleStatusAction(a, 'dictamen'),
        icon: const Icon(Icons.description_outlined, size: 14),
        label: const Text('Dictamen'),
        style: OutlinedButton.styleFrom(
          foregroundColor: OcgColors.bronze,
          side: BorderSide(color: OcgColors.bronze.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ];

    if (a.estado == AppointmentStatus.programada) {
      actions.addAll([
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'confirmar'),
          icon: const Icon(Icons.check_circle_outline, size: 14),
          label: const Text('Confirmar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
            side: const BorderSide(color: Color(0xFF1565C0)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'reprogramar'),
          icon: const Icon(Icons.edit_calendar_outlined, size: 14),
          label: const Text('Reprogramar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: OcgColors.bronze,
            side: const BorderSide(color: OcgColors.bronze),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]);
    } else if (a.estado == AppointmentStatus.confirmada) {
      actions.addAll([
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'completar'),
          icon: const Icon(Icons.done_all, size: 14),
          label: const Text('Completar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2E7D32),
            side: const BorderSide(color: Color(0xFF2E7D32)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'reprogramar'),
          icon: const Icon(Icons.edit_calendar_outlined, size: 14),
          label: const Text('Reprogramar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: OcgColors.bronze,
            side: const BorderSide(color: OcgColors.bronze),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]);
    }

    if (a.estado == AppointmentStatus.completada) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'reabrir'),
          icon: const Icon(Icons.lock_open_outlined, size: 14),
          label: const Text('Reabrir'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
            side: const BorderSide(color: Color(0xFF1565C0)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    if (a.estado == AppointmentStatus.programada ||
        a.estado == AppointmentStatus.confirmada) {
      actions.addAll([
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'no_asistio'),
          icon: const Icon(Icons.person_off_outlined, size: 14),
          label: const Text('No asistió'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC56B16),
            side: const BorderSide(color: Color(0xFFC56B16)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _handleStatusAction(a, 'cancelar'),
          icon: const Icon(Icons.cancel_outlined, size: 14),
          label: const Text('Cancelar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: OcgColors.error,
            side: const BorderSide(color: OcgColors.error),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]);
    }

    return Wrap(spacing: 6, runSpacing: 6, children: actions);
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
  }) {
    final ui = appointmentStatusUi(a);
    final timeLabel = showDate
        ? '${a.fechaHora.day.toString().padLeft(2, '0')}/${a.fechaHora.month.toString().padLeft(2, '0')} · ${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}'
        : '${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}';
    final autoLabel = autoScheduleLabel(a);

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 8 : 10),
      padding: EdgeInsets.all(dense ? 12 : 14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(dense ? 18 : 22),
        border: Border.all(color: ui.line.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.055),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _agendaPill(
                label: agendaOperationalHint(a),
                color: isAgendaIncident(a) ? OcgColors.error : OcgColors.bronze,
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
    );
  }

  Widget _buildQuickFilters(
    List<AppointmentModel> appointments,
    DateTime selectedDate,
  ) {
    final filters = AgendaDayQuickFilter.values;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = _dayQuickFilter == filter;
          final count = quickFilterCount(filter, appointments, selectedDate);
          return ChoiceChip(
            selected: active,
            avatar: Icon(
              quickFilterIcon(filter),
              size: 16,
              color: active ? OcgColors.ivory : OcgColors.espresso,
            ),
            label: Text('${quickFilterLabel(filter)} · $count'),
            selectedColor: OcgColors.espresso,
            backgroundColor: OcgColors.ivory,
            labelStyle: TextStyle(
              color: active ? OcgColors.ivory : OcgColors.espresso,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: active
                  ? OcgColors.espresso
                  : OcgColors.bronze.withOpacity(0.24),
            ),
            onSelected: (_) {
              final now = DateTime.now();
              if (filter == AgendaDayQuickFilter.manana) {
                ref
                    .read(selectedAppointmentsDateProvider.notifier)
                    .setDate(DateTime(now.year, now.month, now.day + 1));
              } else if (filter == AgendaDayQuickFilter.dia) {
                ref
                    .read(selectedAppointmentsDateProvider.notifier)
                    .setDate(DateTime(now.year, now.month, now.day));
              }
              setState(() => _dayQuickFilter = filter);
            },
          );
        },
      ),
    );
  }

  Widget _buildIncidenceSubFilterBar({
    required int perdidas,
    required int canceladas,
    required int reprogramadas,
    required int total,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EDE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0C7AF).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list_outlined,
            size: 16,
            color: Color(0xFF8A6F59),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _incidenceChip(
                    'Todas',
                    Icons.layers_outlined,
                    total,
                    AgendaIncidenceSubFilter.todas,
                  ),
                  const SizedBox(width: 6),
                  _incidenceChip(
                    'Perdidas',
                    Icons.person_off_outlined,
                    perdidas,
                    AgendaIncidenceSubFilter.perdidas,
                    accentColor: OcgColors.error,
                  ),
                  const SizedBox(width: 6),
                  _incidenceChip(
                    'Canceladas',
                    Icons.cancel_outlined,
                    canceladas,
                    AgendaIncidenceSubFilter.canceladas,
                    accentColor: const Color(0xFF888780),
                  ),
                  const SizedBox(width: 6),
                  _incidenceChip(
                    'Reprogramadas',
                    Icons.edit_calendar_outlined,
                    reprogramadas,
                    AgendaIncidenceSubFilter.reprogramadas,
                    accentColor: const Color(0xFF7E3AF2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidenceChip(
    String label,
    IconData icon,
    int count,
    AgendaIncidenceSubFilter filter, {
    Color? accentColor,
  }) {
    final active = _incidenceSubFilter == filter;
    final chipColor = accentColor ?? OcgColors.espresso;
    return ChoiceChip(
      selected: active,
      avatar: Icon(
        icon,
        size: 14,
        color: active ? OcgColors.ivory : chipColor,
      ),
      label: Text('$label · $count'),
      selectedColor: chipColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: active ? OcgColors.ivory : chipColor,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      side: BorderSide(
        color: active ? chipColor : const Color(0xFFD9CCBE),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _incidenceSubFilter = filter),
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

  Widget _buildTodayAgenda(
    BuildContext context,
    List<AppointmentModel> appointments,
    DateTime selectedDate,
  ) {
    var dayItems = quickFilteredItems(
      _dayQuickFilter,
      appointments,
      selectedDate,
    );

    // Sub-filter for Incidencias
    if (_dayQuickFilter == AgendaDayQuickFilter.incidencias) {
      dayItems = dayItems.where((a) {
        return switch (_incidenceSubFilter) {
          AgendaIncidenceSubFilter.todas => true,
          AgendaIncidenceSubFilter.perdidas => isLostAppointment(a),
          AgendaIncidenceSubFilter.canceladas =>
              a.estado == AppointmentStatus.cancelada,
          AgendaIncidenceSubFilter.reprogramadas =>
              a.estado == AppointmentStatus.reprogramada,
        };
      }).toList();
    }

    final total = dayItems.length;
    final confirmadas = dayItems
        .where((a) => a.estado == AppointmentStatus.confirmada)
        .length;
    final activas = dayItems
        .where(
          (a) =>
              a.estado == AppointmentStatus.programada && !isLostAppointment(a),
        )
        .length;
    final completadas = dayItems
        .where((a) => a.estado == AppointmentStatus.completada)
        .length;
    final perdidas = dayItems.where(isLostAppointment).length;
    final canceladas = dayItems
        .where((a) => a.estado == AppointmentStatus.cancelada)
        .length;
    final reprogramadas = dayItems
        .where((a) => a.estado == AppointmentStatus.reprogramada)
        .length;

    Widget? incidenceSubFilterBar;
    if (_dayQuickFilter == AgendaDayQuickFilter.incidencias) {
      incidenceSubFilterBar = _buildIncidenceSubFilterBar(
        perdidas: perdidas,
        canceladas: canceladas,
        reprogramadas: reprogramadas,
        total: total,
      );
    }

    Widget timeline = dayItems.isEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (incidenceSubFilterBar != null) incidenceSubFilterBar,
              _agendaEmptyState(
                title:
                    'Sin citas en ${quickFilterLabel(_dayQuickFilter).toLowerCase()}',
                subtitle:
                    'Usa los filtros rápidos para revisar pendientes, incidencias o historial sin perder el contexto operativo.',
                icon: Icons.event_busy_outlined,
                onPrimary: () => AdminAppointmentsScreen.showCreateDialog(
                  context,
                  ref,
                  baseDate: selectedDate,
                  existingAppointments: appointments,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (incidenceSubFilterBar != null) incidenceSubFilterBar,
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  itemCount: dayItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final a = dayItems[index];
                    return _buildAgendaAppointmentCard(a);
                  },
                ),
              ),
            ],
          );

    Widget summary = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9E4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del día',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _summaryRow('Total', total),
          _summaryRow('Confirmadas', confirmadas),
          _summaryRow('Activas', activas),
          _summaryRow('Completadas', completadas),
          _summaryRow('Perdidas', perdidas),
          _summaryRow('Canceladas', canceladas),
        ],
      ),
    );

    final desktop = WebLayoutContext.useDesktopShell(context);
    if (desktop) {
      return Column(
        children: [
          _buildQuickFilters(appointments, selectedDate),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: OcgColors.ivory,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: OcgColors.bronze.withOpacity(0.22),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: timeline,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: summary),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        const SizedBox(height: 8),
        _buildQuickFilters(appointments, selectedDate),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: summary,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: dayItems.isEmpty
              ? timeline
              : Column(
                  children: [
                    for (final appointment in dayItems)
                      _buildAgendaAppointmentCard(appointment),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: OcgColors.ink.withOpacity(0.86),
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
        ],
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

  Widget _buildMonthAgenda(
    BuildContext context,
    List<AppointmentModel> appointments,
  ) {
    final firstWeekday =
        DateTime(_monthCursor.year, _monthCursor.month, 1).weekday % 7;
    final daysInMonth = DateTime(
      _monthCursor.year,
      _monthCursor.month + 1,
      0,
    ).day;
    final today = DateTime.now();
    final selected = _selectedMonthDay;
    final selectedItems = selected == null
        ? const <AppointmentModel>[]
        : appointmentsForDay(appointments, selected);

    final calendarCells = <Widget>[];
    const dow = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    calendarCells.addAll(
      dow.map(
        (d) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              d,
              style: TextStyle(
                fontSize: 11,
                color: OcgColors.ink.withOpacity(0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < firstWeekday; i++) {
      calendarCells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_monthCursor.year, _monthCursor.month, day);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected =
          selected != null &&
          date.year == selected.year &&
          date.month == selected.month &&
          date.day == selected.day;
      final dayItems = appointmentsForDay(appointments, date);

      calendarCells.add(
        InkWell(
          onTap: () => setState(() => _selectedMonthDay = date),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? OcgColors.espresso : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday
                    ? OcgColors.espresso
                    : OcgColors.bronze.withOpacity(0.15),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? OcgColors.ivory : OcgColors.ink,
                  ),
                ),
                if (dayItems.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 2,
                    children: dayItems.take(3).map((a) {
                      final ui = appointmentStatusUi(a);
                      return Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? OcgColors.ivory.withOpacity(0.8)
                              : ui.dot,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final isMobileMonthView = MediaQuery.of(context).size.width < 900;

    Widget detailPanel = Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: selected == null
          ? _agendaEmptyState(
              title: 'Selecciona un día',
              subtitle:
                  'Toca una fecha del calendario para ver agenda, incidencias y acciones rápidas.',
              icon: Icons.calendar_month_outlined,
            )
          : selectedItems.isEmpty
          ? _agendaEmptyState(
              title: 'Sin citas este día',
              subtitle: 'Puedes crear una cita directamente para esta fecha.',
              icon: Icons.event_available_outlined,
              onPrimary: () => AdminAppointmentsScreen.showCreateDialog(
                context,
                ref,
                baseDate: selected,
                existingAppointments: appointments,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${selectedItems.length} cita(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OcgColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isMobileMonthView)
                  ListView.builder(
                    itemCount: selectedItems.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) =>
                        _buildAgendaAppointmentCard(
                          selectedItems[index],
                          dense: true,
                        ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: selectedItems.length,
                      itemBuilder: (context, index) =>
                          _buildAgendaAppointmentCard(
                            selectedItems[index],
                            dense: true,
                          ),
                    ),
                  ),
              ],
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AdminDesktopLayoutScope.maybeOf(context);
        final shouldSplit =
            layout?.shouldKeepSplit(
              primaryMinWidth: 300,
              secondaryMinWidth: 420,
            ) ??
            constraints.maxWidth >= 900;
        final panelGap = layout?.panelGap ?? 12;
        final tier = layout?.tier ?? AdminDesktopTier.standard;
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
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      agendaMonthLabel(_monthCursor),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OcgColors.espresso,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: shouldSplit ? 1.12 : 1.25,
                children: calendarCells,
              ),
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
            children: [calendarCard, const SizedBox(height: 10), detailPanel],
          ),
        );
      },
    );
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
                (a) => _buildAgendaAppointmentCard(
                  a,
                  showDate: true,
                  dense: true,
                ),
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

  Widget _buildMobileAgendaHero(
    BuildContext context,
    List<AppointmentModel> appointments,
    DateTime selectedDate,
  ) {
    final dayItems = appointmentsForDay(appointments, selectedDate);
    final now = DateTime.now();
    final upcoming =
        appointments
            .where(
              (a) =>
                  a.fechaHora.isAfter(now) &&
                  (a.estado == AppointmentStatus.programada ||
                      a.estado == AppointmentStatus.confirmada),
            )
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    final pendientes = dayItems
        .where(
          (a) =>
              a.estado == AppointmentStatus.programada ||
              a.estado == AppointmentStatus.confirmada,
        )
        .length;
    final incidencias = dayItems.where(isAgendaIncident).length;
    final completadas = dayItems
        .where((a) => a.estado == AppointmentStatus.completada)
        .length;
    final next = upcoming.isEmpty ? null : upcoming.first;

    Widget metric(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: OcgColors.ivory.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: OcgColors.ivory.withOpacity(0.78),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.74),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OcgColors.ivory,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget action({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool filled = false,
    }) {
      final foreground = filled ? OcgColors.espresso : OcgColors.ivory;
      return filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 17),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.ivory,
                foregroundColor: foreground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 17),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: BorderSide(color: OcgColors.ivory.withOpacity(0.34)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3527), Color(0xFF9A7654)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 8,
          16,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OcgColors.ivory.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: OcgColors.ivory.withOpacity(0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: OcgColors.ivory,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agenda clínica',
                        style: TextStyle(
                          color: OcgColors.ivory,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Día seleccionado: ${appointmentFmtDate(selectedDate)}',
                        style: TextStyle(
                          color: OcgColors.ivory.withOpacity(0.82),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (next == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
                ),
                child: const Text(
                  'No hay próximas citas activas registradas.',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      color: OcgColors.ivory,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Próxima: ${next.patientName} · ${appointmentFmtDateTime(next.fechaHora)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OcgColors.ivory,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                metric('Total día', '${dayItems.length}', Icons.today_outlined),
                const SizedBox(width: 8),
                metric('Pendientes', '$pendientes', Icons.schedule_outlined),
                const SizedBox(width: 8),
                metric(
                  'Incidencias',
                  '$incidencias',
                  Icons.warning_amber_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                metric('Completadas', '$completadas', Icons.done_all_outlined),
                const SizedBox(width: 8),
                metric(
                  'Próximas',
                  '${upcoming.length}',
                  Icons.event_note_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                action(
                  label: 'Nueva cita',
                  icon: Icons.add_circle_outline,
                  filled: true,
                  onTap: () => AdminAppointmentsScreen.showCreateDialog(
                    context,
                    ref,
                    baseDate: selectedDate,
                    existingAppointments: appointments,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final loadedAppointments =
        appointmentsAsync.asData?.value ?? const <AppointmentModel>[];

    final hoyAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) =>
          _buildTodayAgenda(context, appointments, selectedDate),
    );

    final mesAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildMonthAgenda(context, appointments),
    );

    final historialAgendaBody = appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildHistoryAgenda(context, appointments),
    );

    final agendaBody = switch (_innerTab) {
      AgendaInnerTab.hoy => hoyAgendaBody,
      AgendaInnerTab.mes => mesAgendaBody,
      AgendaInnerTab.historial => historialAgendaBody,
    };

    final subtitleByTab = switch (_innerTab) {
      AgendaInnerTab.hoy => 'Seguimiento diario con timeline y resumen',
      AgendaInnerTab.mes => 'Vista mensual con detalle por día',
      AgendaInnerTab.historial => 'Historial por estado y mes',
    };

    final panelTitleByTab = switch (_innerTab) {
      AgendaInnerTab.hoy => 'Hoy',
      AgendaInnerTab.mes => 'Mes',
      AgendaInnerTab.historial => 'Historial',
    };

    final mobileContent = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: _buildMobileAgendaHero(context, loadedAppointments, selectedDate),
          ),
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
          SectionPanel(
            title: panelTitleByTab,
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
            child: SizedBox(
              height: 720,
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ─────────────────────────────────────────────────
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${appointmentTypeLabel(appointment.tipo)} · '
              '${appointmentFmtDateTime(appointment.fechaHora)} · '
              '${appointment.duracionMinutos} min',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (appointment.notas != null && appointment.notas!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                appointment.notas!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
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
                    Icon(Icons.timeline_outlined, size: 12, color: OcgColors.bronze),
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
