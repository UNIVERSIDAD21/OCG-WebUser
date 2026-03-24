import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/data/models/availability_day_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/providers/availability_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../../../shared/utils/ui_formatters.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../../presentation/web/common/web_layout_context.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';

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
                      if (v == null) return;
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
                      if (amount <= 0)
                        return 'Ingresa un monto válido mayor que 0';
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

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
  _AgendaFilter _filter = _AgendaFilter.hoy;

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

                    final slots = AppointmentsBusinessRules.buildDailySlots(
                      day: d,
                      existingAppointments: existingAppointments,
                      durationMinutes: newDuration,
                      excludeAppointmentId: appt.id,
                      stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
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
                    final slots = AppointmentsBusinessRules.buildDailySlots(
                      day: newDateTime,
                      existingAppointments: existingAppointments,
                      durationMinutes: newDuration,
                      excludeAppointmentId: appt.id,
                      stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
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
                    final slots = AppointmentsBusinessRules.buildDailySlots(
                      day: newDateTime,
                      existingAppointments: existingAppointments,
                      durationMinutes: nextDuration,
                      excludeAppointmentId: appt.id,
                      stepMinutes: AppointmentsBusinessRules.slotStepMinutes,
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

  List<AppointmentModel> _applyFilter(
    List<AppointmentModel> all,
    DateTime selectedDate,
  ) {
    switch (_filter) {
      case _AgendaFilter.hoy:
        return all
            .where(
              (a) =>
                  a.fechaHora.year == selectedDate.year &&
                  a.fechaHora.month == selectedDate.month &&
                  a.fechaHora.day == selectedDate.day &&
                  a.estado != AppointmentStatus.cancelada &&
                  a.estado != AppointmentStatus.reprogramada &&
                  a.estado != AppointmentStatus.completada,
            )
            .toList();
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
        return all
            .where(
              (a) => _esPerdida(a) && a.estado != AppointmentStatus.completada,
            )
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
      case _AgendaFilter.canceladas:
        return all
            .where((a) => a.estado == AppointmentStatus.cancelada)
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    }
  }

  Widget _buildList(List<AppointmentModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (_filter) {
                _AgendaFilter.perdidas => Icons.event_busy_outlined,
                _AgendaFilter.canceladas => Icons.cancel_outlined,
                _ => Icons.event_note_outlined,
              },
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final appt = items[index];
        final repo = ref.read(appointmentsRepositoryProvider);

        return switch (_filter) {
          _AgendaFilter.hoy || _AgendaFilter.activas => AppointmentCard(
            appointment: appt,
            onConfirmar: appt.estado == AppointmentStatus.programada
                ? () async => repo.updateAppointmentStatus(
                    appt.id,
                    AppointmentStatus.confirmada,
                  )
                : null,
            onCompletar: appt.estado == AppointmentStatus.confirmada
                ? () async => _onCompletarCitaConDictamen(appt)
                : null,
            onReprogramar: () => _showRescheduleDialog(appt),
            onCancelar: () => _showCancelDialog(appt),
          ),
          _AgendaFilter.completadas => AppointmentCard(
            appointment: appt,
            onReabrirCompletada: () => _onReabrirCompletada(appt),
            onNoCompletada: () => _onNoCompletada(appt),
          ),
          _ => AppointmentCard(appointment: appt),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    final agendaBody = Column(
      children: [
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
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_AgendaFilter>(
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return switch (_filter) {
                    _AgendaFilter.perdidas => OcgColors.error,
                    _AgendaFilter.canceladas => const Color(0xFF6D4C41),
                    _ => OcgColors.espresso,
                  };
                }
                return OcgColors.ivory;
              }),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? OcgColors.ivory
                    : OcgColors.ink,
              ),
              side: const WidgetStatePropertyAll(BorderSide(color: OcgColors.bronze)),
            ),
            segments: const [
              ButtonSegment(value: _AgendaFilter.hoy, label: Text('Por fecha')),
              ButtonSegment(value: _AgendaFilter.activas, label: Text('Activas')),
              ButtonSegment(value: _AgendaFilter.completadas, label: Text('Completadas')),
              ButtonSegment(value: _AgendaFilter.perdidas, label: Text('Perdidas')),
              ButtonSegment(value: _AgendaFilter.canceladas, label: Text('Canceladas')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(
          child: appointmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('No se pudo cargar agenda: $e')),
            data: (appointments) {
              final filtered = _applyFilter(appointments, selectedDate);
              return _buildList(filtered);
            },
          ),
        ),
      ],
    );

    if (WebLayoutContext.useDesktopShell(context)) {
      return AdminWebShell(
        currentRoute: '/admin/appointments',
        title: 'Agenda',
        child: agendaBody,
      );
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 2,
      title: 'Agenda de citas',
      appBarActions: [
        IconButton(
          tooltip: 'Crear cuenta de paciente',
          icon: const Icon(Icons.person_add_outlined),
          onPressed: () => AdminAppointmentsScreen.showCreatePatientAccountDialog(context, ref),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, color: OcgColors.error),
          onPressed: _handleSignOut,
        ),
      ],
      body: agendaBody,
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
      AppointmentStatus.programada => OcgColors.bronze,
      AppointmentStatus.confirmada => const Color(0xFF1565C0),
      AppointmentStatus.completada => const Color(0xFF2E7D32),
      AppointmentStatus.cancelada => OcgColors.error,
      AppointmentStatus.noAsistio => OcgColors.error,
      AppointmentStatus.reprogramada => Colors.purple,
    };

    final String statusLabel = switch (appointment.estado) {
      AppointmentStatus.programada => 'Programada',
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
