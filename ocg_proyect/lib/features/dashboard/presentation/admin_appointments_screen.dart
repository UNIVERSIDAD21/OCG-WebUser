import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/data/models/availability_day_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/providers/availability_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../admin/presentation/web/components/section_panel.dart';
import '../../admin/presentation/web/components/action_toolbar.dart';
import '../../admin/presentation/web/components/page_header.dart';

String _appointmentFmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _appointmentFmtDateTime(DateTime d) =>
    '${_appointmentFmtDate(d)} ${() {
      final h = d.hour == 0
          ? 12
          : d.hour > 12
          ? d.hour - 12
          : d.hour;
      final ap = d.hour < 12 ? 'AM' : 'PM';
      return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
    }()}';

String _appointmentDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

enum _AgendaFilter { hoy, activas, completadas, perdidas, canceladas }
enum _AgendaInnerTab { hoy, mes, historial }

bool _esPerdida(AppointmentModel a) {
  if (a.estado == AppointmentStatus.noAsistio) return true;
  if (a.estado == AppointmentStatus.programada) {
    final limite = DateTime.now().subtract(const Duration(days: 1));
    return a.fechaHora.isBefore(limite);
  }
  return false;
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

String _labelTipoTratamiento(TreatmentType type) {
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

// ─── AdminAppointmentsScreen ──────────────────────────────────────────────────

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

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
    TreatmentType treatmentType = TreatmentType.convencional;
    final totalTreatmentCtrl = TextEditingController();

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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TreatmentType>(
                    initialValue: treatmentType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de tratamiento',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: TreatmentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(_labelTipoTratamiento(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setDs(() => treatmentType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: totalTreatmentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto total del tratamiento (COP)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      final amount = double.tryParse(digits) ?? 0;
                      if (amount <= 0) {
                        return 'Ingresa un monto válido mayor que 0';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.isEmpty) return;
                      final formatted = formatCop(double.parse(digits));
                      if (formatted == totalTreatmentCtrl.text) return;
                      totalTreatmentCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
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
                      final totalRaw = totalTreatmentCtrl.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      final totalTreatment = double.tryParse(totalRaw) ?? 0;

                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .createPatientByAdmin(
                              email: email.trim(),
                              password: pass,
                              displayName: name.trim(),
                              treatmentType: treatmentType.name,
                              totalTreatment: totalTreatment,
                            );
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

    totalTreatmentCtrl.dispose();
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
  AppointmentType _type = AppointmentType.control;
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
    });
  }

  Future<void> _submit() async {
    if (_selectedPatient == null) {
      setState(() => _errorMsg = 'Selecciona un paciente de la lista.');
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
              tipo: _type,
              estado: AppointmentStatus.programada,
              fechaHora: _dateTime,
              duracionMinutos: _durationMinutes,
              notas: notasTexto.isEmpty ? null : notasTexto,
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

  @override
  Widget build(BuildContext context) {
    // ✅ ref.watch() aquí — si el stream emite, solo rebuild este widget,
    //    sin destruir ni recrear el árbol del AlertDialog.
    final patients =
        ref.watch(patientsStreamProvider).asData?.value ?? const [];
    final availability = ref
        .watch(availabilityByDayProvider(_appointmentDayKey(_dateTime)))
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
                onChanged: (_) => setState(() => _selectedPatient = null),
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
                              title: Text(p.nombre),
                              subtitle: Text(
                                p.telefono,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setState(() {
                                _selectedPatient = p;
                                _searchCtrl.text = p.nombre;
                              }),
                            );
                          }).toList(),
                        ),
                ),
              ],

              // ── Chip del paciente seleccionado ─────────────────────────
              if (_selectedPatient != null) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(
                    Icons.person,
                    size: 14,
                    color: OcgColors.ivory,
                  ),
                  label: Text(_selectedPatient!.nombre),
                  backgroundColor: OcgColors.espresso,
                  labelStyle: const TextStyle(color: OcgColors.ivory),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 14,
                    color: OcgColors.ivory,
                  ),
                  onDeleted: () => setState(() {
                    _selectedPatient = null;
                    _searchCtrl.clear();
                  }),
                ),
              ],

              const SizedBox(height: 12),

              // ── Tipo ───────────────────────────────────────────────────
              DropdownButtonFormField<AppointmentType>(
                initialValue: _type,
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
                    setState(() => _type = v ?? AppointmentType.control),
              ),
              const SizedBox(height: 10),

              // ── Fecha y hora ───────────────────────────────────────────
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: OcgColors.espresso),
                title: const Text('Fecha y hora'),
                subtitle: Text(
                  _appointmentFmtDateTime(_dateTime),
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
                      onSelected: slot.isAvailable
                          ? (_) => setState(() => _dateTime = slot.start)
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
  _AgendaInnerTab _innerTab = _AgendaInnerTab.hoy;
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedMonthDay;
  _AgendaFilter _historyFilter = _AgendaFilter.activas;
  int _historyPage = 1;

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión de administrador?'),
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
          .read(availabilityByDayProvider(_appointmentDayKey(newDateTime)))
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
                  title: Text(_appointmentFmtDateTime(newDateTime)),
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
                          .read(availabilityByDayProvider(_appointmentDayKey(d)))
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
                      return ChoiceChip(
                        label: Text(slot.label),
                        selected: slot.start == newDateTime,
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

  Future<void> _onNoCompletada(AppointmentModel appt) async {
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, AppointmentStatus.noAsistio);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Future<void> _onCompletarCitaConDictamen(AppointmentModel appt) async {
    try {
      if (appt.tipo != AppointmentType.valoracion) {
        await ref
            .read(appointmentsRepositoryProvider)
            .updateAppointmentStatus(appt.id, AppointmentStatus.completada);
        return;
      }

      final patient = await ref.read(
        patientByIdProvider(appt.patientId).future,
      );
      final alreadyDefined = patient?.tipoTratamiento != null;

      if (!alreadyDefined) {
        final decision = await _showValoracionDictamenDialog(
          patientName: appt.patientName,
        );
        if (decision == null) return;

        await ref
            .read(patientsRepositoryProvider)
            .defineInitialTreatmentPlanAndFinance(
              patientId: appt.patientId,
              tipoTratamiento: decision['tipoTratamiento'] as TreatmentType,
              totalTratamiento: decision['totalTratamiento'] as double,
              etapaActual: TreatmentStage.estudioPlaneacion,
              notasClinicas: (decision['nota'] as String?)?.trim() ?? '',
              fechaProximoPago: decision['fechaProximoPago'] as DateTime?,
            );
      }

      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appt.id, AppointmentStatus.completada);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita completada y dictamen inicial registrado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la cita: $e')),
      );
    }
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
                            child: Text(_labelTipoTratamiento(t)),
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
                              : 'Próximo pago: ${_appointmentFmtDate(fechaProximoPago!)}',
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

  String _labelTipoTratamiento(TreatmentType type) {
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

  Widget _buildInnerTabs() {
    Widget item(_AgendaInnerTab tab, String label) {
      final active = _innerTab == tab;
      return TextButton(
        onPressed: () => setState(() => _innerTab = tab),
        style: TextButton.styleFrom(
          foregroundColor: active ? OcgColors.espresso : OcgColors.ink,
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
        border: Border(bottom: BorderSide(color: OcgColors.bronze.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          item(_AgendaInnerTab.hoy, 'Hoy'),
          item(_AgendaInnerTab.mes, 'Mes'),
          item(_AgendaInnerTab.historial, 'Historial'),
        ],
      ),
    );
  }

  List<AppointmentModel> _appointmentsForDay(
    List<AppointmentModel> all,
    DateTime day,
  ) {
    final list = all
        .where(
          (a) =>
              a.fechaHora.year == day.year &&
              a.fechaHora.month == day.month &&
              a.fechaHora.day == day.day &&
              a.estado != AppointmentStatus.reprogramada,
        )
        .toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return list;
  }

  ({Color dot, Color line, String label}) _statusUi(AppointmentModel a) {
    if (_esPerdida(a)) {
      return (dot: OcgColors.error, line: OcgColors.error, label: 'Perdida');
    }

    return switch (a.estado) {
      AppointmentStatus.programada => (
        dot: const Color(0xFFBA7517),
        line: const Color(0xFFBA7517),
        label: 'Activa',
      ),
      AppointmentStatus.confirmada => (
        dot: const Color(0xFF639922),
        line: const Color(0xFF639922),
        label: 'Confirmada',
      ),
      AppointmentStatus.completada => (
        dot: const Color(0xFF1B45A0),
        line: const Color(0xFF1B45A0),
        label: 'Completada',
      ),
      AppointmentStatus.cancelada => (
        dot: const Color(0xFF888780),
        line: const Color(0xFF888780),
        label: 'Cancelada',
      ),
      AppointmentStatus.noAsistio => (
        dot: OcgColors.error,
        line: OcgColors.error,
        label: 'Perdida',
      ),
      AppointmentStatus.reprogramada => (
        dot: Colors.purple,
        line: Colors.purple,
        label: 'Reprogramada',
      ),
    };
  }

  Future<void> _handleStatusAction(AppointmentModel a, String action) async {
    switch (action) {
      case 'confirmar':
        await ref
            .read(appointmentsRepositoryProvider)
            .updateAppointmentStatus(a.id, AppointmentStatus.confirmada);
        break;
      case 'completar':
        await _onCompletarCitaConDictamen(a);
        break;
      case 'reprogramar':
        await _showRescheduleDialog(a);
        break;
      case 'cancelar':
        await _showCancelDialog(a);
        break;
      case 'reabrir':
        await _onReabrirCompletada(a);
        break;
    }
  }

  void _openPatientProfile(String patientId) {
    if (patientId.trim().isEmpty) return;
    context.go(RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId));
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

    if (a.estado == AppointmentStatus.programada || a.estado == AppointmentStatus.confirmada) {
      actions.add(
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
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: actions);
  }

  Widget _buildTodayAgenda(
    BuildContext context,
    List<AppointmentModel> appointments,
    DateTime selectedDate,
  ) {
    final dayItems = _appointmentsForDay(appointments, selectedDate);
    final total = dayItems.length;
    final confirmadas = dayItems
        .where((a) => a.estado == AppointmentStatus.confirmada)
        .length;
    final activas = dayItems
        .where(
          (a) =>
              a.estado == AppointmentStatus.programada && !_esPerdida(a),
        )
        .length;
    final completadas = dayItems
        .where((a) => a.estado == AppointmentStatus.completada)
        .length;
    final perdidas = dayItems.where(_esPerdida).length;
    final canceladas = dayItems
        .where((a) => a.estado == AppointmentStatus.cancelada)
        .length;

    Widget timeline = dayItems.isEmpty
        ? Center(
            child: Text(
              'Sin citas para este día',
              style: TextStyle(color: OcgColors.ink.withOpacity(0.55)),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            itemCount: dayItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = dayItems[index];
              final ui = _statusUi(a);
              final isLast = index == dayItems.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: OcgColors.ink.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 14),
                        decoration: BoxDecoration(
                          color: ui.dot,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 44,
                          color: OcgColors.bronze.withOpacity(0.25),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OcgColors.ivory,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: OcgColors.bronze.withOpacity(0.22),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 44,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: ui.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.patientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: OcgColors.espresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_labelTipo(a.tipo)} · ${a.duracionMinutos} min · ${ui.label}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: OcgColors.ink.withOpacity(0.72),
                                  ),
                                ),
                                if ((a.notas ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Notas clínicas: ${a.notas!.trim()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: OcgColors.ink.withOpacity(0.78),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _buildAppointmentActionsInline(a),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OcgColors.bronze.withOpacity(0.22)),
              ),
              padding: const EdgeInsets.all(10),
              child: timeline,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: summary),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: summary,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: timeline,
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

  String _monthLabel(DateTime d) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _buildMonthAgenda(
    BuildContext context,
    List<AppointmentModel> appointments,
  ) {
    final firstWeekday = DateTime(_monthCursor.year, _monthCursor.month, 1)
        .weekday %
        7;
    final daysInMonth = DateTime(
      _monthCursor.year,
      _monthCursor.month + 1,
      0,
    ).day;
    final today = DateTime.now();
    final selected = _selectedMonthDay;
    final selectedItems = selected == null
        ? const <AppointmentModel>[]
        : _appointmentsForDay(appointments, selected);

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
      final dayItems = _appointmentsForDay(appointments, date);

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
                      final ui = _statusUi(a);
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

    Widget detailPanel = Container(
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: selected == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 32,
                    color: OcgColors.ink.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona un día para ver sus citas',
                    style: TextStyle(color: OcgColors.ink.withOpacity(0.6)),
                  ),
                ],
              ),
            )
          : selectedItems.isEmpty
          ? Center(
              child: Text(
                'Sin citas este día',
                style: TextStyle(color: OcgColors.ink.withOpacity(0.6)),
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
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedItems.length,
                    itemBuilder: (context, index) {
                      final a = selectedItems[index];
                      final ui = _statusUi(a);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OcgColors.ivory,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: OcgColors.bronze.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 36,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: ui.line,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')} · ${a.patientName}',
                                    style: TextStyle(
                                      color: OcgColors.ink.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_labelTipo(a.tipo)} · ${ui.label}',
                                    style: TextStyle(
                                      color: OcgColors.ink.withOpacity(0.72),
                                    ),
                                  ),
                                  if ((a.notas ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notas clínicas: ${a.notas!.trim()}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: OcgColors.ink.withOpacity(0.78),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  _buildAppointmentActionsInline(a),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
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
                      _monthLabel(_monthCursor),
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
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: calendarCells,
              ),
            ],
          ),
        );

        if (isDesktop) {
          return Row(
            children: [
              SizedBox(width: 340, child: calendarCard),
              const SizedBox(width: 12),
              Expanded(child: detailPanel),
            ],
          );
        }

        return Column(
          children: [
            calendarCard,
            const SizedBox(height: 10),
            SizedBox(height: 380, child: detailPanel),
          ],
        );
      },
    );
  }

  String _historyMonthLabel(DateTime d) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  List<AppointmentModel> _historyItems(List<AppointmentModel> all) {
    final now = DateTime.now();
    final past = all
        .where((a) => a.fechaHora.isBefore(now))
        .where((a) => a.estado != AppointmentStatus.reprogramada)
        .toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

    final filtered = switch (_historyFilter) {
      _AgendaFilter.completadas =>
        past.where((a) => a.estado == AppointmentStatus.completada).toList(),
      _AgendaFilter.perdidas => past.where(_esPerdida).toList(),
      _AgendaFilter.canceladas =>
        past.where((a) => a.estado == AppointmentStatus.cancelada).toList(),
      _ => past,
    };

    final pageSize = 12;
    final max = _historyPage * pageSize;
    return filtered.take(max).toList();
  }

  int _historyCountByFilter(List<AppointmentModel> all, _AgendaFilter filter) {
    final now = DateTime.now();
    final past = all
        .where((a) => a.fechaHora.isBefore(now))
        .where((a) => a.estado != AppointmentStatus.reprogramada)
        .toList();

    return switch (filter) {
      _AgendaFilter.completadas =>
        past.where((a) => a.estado == AppointmentStatus.completada).length,
      _AgendaFilter.perdidas => past.where(_esPerdida).length,
      _AgendaFilter.canceladas =>
        past.where((a) => a.estado == AppointmentStatus.cancelada).length,
      _ => past.length,
    };
  }

  Widget _historyFilterItem(String label, _AgendaFilter filter, int count) {
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
    final items = _historyItems(appointments);
    final totalFiltered = _historyCountByFilter(appointments, _historyFilter);
    final hasMore = items.length < totalFiltered;

    final groups = <String, List<AppointmentModel>>{};
    for (final item in items) {
      final key = '${item.fechaHora.year}-${item.fechaHora.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget list = sortedKeys.isEmpty
        ? Center(
            child: Text(
              'Sin citas en historial para este filtro',
              style: TextStyle(color: OcgColors.ink.withOpacity(0.55)),
            ),
          )
        : ListView(
            padding: const EdgeInsets.only(right: 6),
            children: [
              for (final key in sortedKeys) ...[
                Builder(
                  builder: (_) {
                    final sample = groups[key]!.first.fechaHora;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Text(
                        _historyMonthLabel(DateTime(sample.year, sample.month, 1)).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.ink.withOpacity(0.6),
                        ),
                      ),
                    );
                  },
                ),
                ...groups[key]!.map((a) {
                  final ui = _statusUi(a);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OcgColors.ivory,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: OcgColors.bronze.withOpacity(0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 36,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: ui.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a.fechaHora.day.toString().padLeft(2, '0')}/${a.fechaHora.month.toString().padLeft(2, '0')} ${a.fechaHora.hour.toString().padLeft(2, '0')}:${a.fechaHora.minute.toString().padLeft(2, '0')} · ${a.patientName} · ${_labelTipo(a.tipo)} · ${ui.label}',
                                style: TextStyle(color: OcgColors.ink.withOpacity(0.86)),
                              ),
                              if ((a.notas ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Notas clínicas: ${a.notas!.trim()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: OcgColors.ink.withOpacity(0.78),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => _openPatientProfile(a.patientId),
                                icon: const Icon(Icons.person_outline, size: 14),
                                label: const Text('Ver perfil'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: OcgColors.espresso,
                                  side: BorderSide(
                                    color: OcgColors.espresso.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
                      'Cargar más...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: OcgColors.ink.withOpacity(0.8)),
                    ),
                  ),
                ),
            ],
          );

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
            _AgendaFilter.activas,
            _historyCountByFilter(appointments, _AgendaFilter.activas),
          ),
          _historyFilterItem(
            'Completadas',
            _AgendaFilter.completadas,
            _historyCountByFilter(appointments, _AgendaFilter.completadas),
          ),
          _historyFilterItem(
            'Perdidas',
            _AgendaFilter.perdidas,
            _historyCountByFilter(appointments, _AgendaFilter.perdidas),
          ),
          _historyFilterItem(
            'Canceladas',
            _AgendaFilter.canceladas,
            _historyCountByFilter(appointments, _AgendaFilter.canceladas),
          ),
        ],
      ),
    );

    final isDesktop = WebLayoutContext.useDesktopShell(context);
    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: list),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: filtersPanel),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: filtersPanel,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: list,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    final hoyAgendaBody = appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildTodayAgenda(context, appointments, selectedDate),
    );

    final mesAgendaBody = appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildMonthAgenda(context, appointments),
    );

    final historialAgendaBody = appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
      data: (appointments) => _buildHistoryAgenda(context, appointments),
    );

    final agendaBody = switch (_innerTab) {
      _AgendaInnerTab.hoy => hoyAgendaBody,
      _AgendaInnerTab.mes => mesAgendaBody,
      _AgendaInnerTab.historial => historialAgendaBody,
    };

    final subtitleByTab = switch (_innerTab) {
      _AgendaInnerTab.hoy => 'Seguimiento diario con timeline y resumen',
      _AgendaInnerTab.mes => 'Vista mensual con detalle por día',
      _AgendaInnerTab.historial => 'Historial por estado y mes',
    };

    final panelTitleByTab = switch (_innerTab) {
      _AgendaInnerTab.hoy => 'Hoy',
      _AgendaInnerTab.mes => 'Mes',
      _AgendaInnerTab.historial => 'Historial',
    };

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
                  _buildInnerTabs(),
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

    return OcgAdaptiveScaffold(
      selectedIndex: 2,
      title: 'Agenda de citas',
      appBarActions: [
        IconButton(
          tooltip: 'Crear cuenta de paciente',
          icon: const Icon(Icons.person_add_outlined),
          onPressed: () =>
              AdminAppointmentsScreen.showCreatePatientAccountDialog(
                context,
                ref,
              ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, color: OcgColors.error),
          onPressed: _handleSignOut,
        ),
      ],
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
      body: Column(
        children: [
          _buildInnerTabs(),
          Expanded(child: agendaBody),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: selectedDate,
          existingAppointments: appointmentsAsync.asData?.value ?? const [],
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
    this.onReabrirCompletada,
    this.onNoCompletada,
  });

  final AppointmentModel appointment;
  final Future<void> Function()? onConfirmar;
  final Future<void> Function()? onCompletar;
  final VoidCallback? onReprogramar;
  final VoidCallback? onCancelar;
  final Future<void> Function()? onReabrirCompletada;
  final Future<void> Function()? onNoCompletada;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = switch (appointment.estado) {
      AppointmentStatus.programada => const Color(0xFFBA7517),
      AppointmentStatus.confirmada => const Color(0xFF1565C0),
      AppointmentStatus.completada => const Color(0xFF2E7D32),
      AppointmentStatus.cancelada => OcgColors.error,
      AppointmentStatus.noAsistio => OcgColors.error,
      AppointmentStatus.reprogramada => Colors.purple,
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
              '${_labelTipo(appointment.tipo)} · '
              '${_appointmentFmtDateTime(appointment.fechaHora)} · '
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

            // ── Acciones ─────────────────────────────────────────────────
            if (onConfirmar != null ||
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
