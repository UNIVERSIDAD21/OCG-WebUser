import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/utils/validators.dart';

String _appointmentFmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _appointmentFmtDateTime(DateTime date) =>
    '${_appointmentFmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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

// ─── AdminAppointmentsScreen ──────────────────────────────────────────────────

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  // ─── Diálogo crear cita ───────────────────────────────────────────────────

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
      builder: (ctx) => Consumer(
        builder: (ctx, dialogRef, _) {
          final patients =
              dialogRef.watch(patientsStreamProvider).asData?.value ?? [];
          return StatefulBuilder(
            builder: (ctx, setDs) {
              final filtered = patientSearchCtrl.text.isEmpty
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
                    children: [
                      TextFormField(
                        controller: patientSearchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Buscar paciente',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                        onChanged: (_) => setDs(() => selectedPatient = null),
                      ),
                      if (patientSearchCtrl.text.isNotEmpty &&
                          selectedPatient == null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              title: Text(filtered[i].nombre),
                              subtitle: Text(
                                filtered[i].telefono,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setDs(() {
                                selectedPatient = filtered[i];
                                patientSearchCtrl.text = filtered[i].nombre;
                              }),
                            ),
                          ),
                        ),
                      if (selectedPatient != null)
                        Chip(
                          avatar: const Icon(
                            Icons.person,
                            size: 14,
                            color: OcgColors.ivory,
                          ),
                          label: Text(selectedPatient!.nombre),
                          backgroundColor: OcgColors.espresso,
                          labelStyle: const TextStyle(color: OcgColors.ivory),
                          deleteIconColor: OcgColors.ivory,
                          onDeleted: () => setDs(() {
                            selectedPatient = null;
                            patientSearchCtrl.clear();
                          }),
                        ),
                      const SizedBox(height: 8),
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
                        onChanged: (v) => setDs(() => type = v ?? type),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(_appointmentFmtDateTime(dateTime)),
                        subtitle: const Text('Fecha y hora'),
                        trailing: const Icon(Icons.edit, size: 16),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dateTime,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (d == null) return;
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(dateTime),
                          );
                          if (t == null) return;
                          setDs(
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
                            setDs(() => durationMinutes = v ?? 30),
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
                    onPressed: selectedPatient == null
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            try {
                              await ref
                                  .read(appointmentsRepositoryProvider)
                                  .createAppointment(
                                    AppointmentModel(
                                      id: '',
                                      patientId: selectedPatient!.id,
                                      patientName: selectedPatient!.nombre,
                                      // ✅ campos nuevos
                                      patientPhone: selectedPatient!.telefono,
                                      creadoPor: 'admin',
                                      tipo: type,
                                      estado: AppointmentStatus.programada,
                                      fechaHora: dateTime,
                                      duracionMinutos: durationMinutes,
                                      notas: notesCtrl.text.trim().isEmpty
                                          ? null
                                          : notesCtrl.text.trim(),
                                    ),
                                  );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Cita creada.')),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('No se pudo crear: $e'),
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
      ),
    );
    patientSearchCtrl.dispose();
    notesCtrl.dispose();
  }

  // ─── ✅ NUEVO: Diálogo crear cuenta de paciente (admin) ───────────────────

  static Future<void> showCreatePatientAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMsg;

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
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: Validators.fullName,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña temporal',
                      prefixIcon: Icon(Icons.lock_outlined),
                      helperText: 'El paciente puede cambiarla desde la app',
                    ),
                    validator: Validators.passwordForRegister,
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
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
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
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      setDs(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });

                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .registerPatient(
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text,
                              displayName: nameCtrl.text.trim(),
                            );

                        // ✅ Sign out de la sesión del paciente creado.
                        // registerPatient inicia sesión con el nuevo user;
                        // cerramos esa sesión para que el admin recupere
                        // su sesión al re-autenticarse.
                        // TODO(bloque-09): migrar a Cloud Function para
                        // evitar interrumpir la sesión del admin.
                        await ref.read(authServiceProvider).signOut();

                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✓ Cuenta creada para ${nameCtrl.text.trim()}. '
                                'Vuelve a iniciar sesión.',
                              ),
                              duration: const Duration(seconds: 6),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg;
                        switch (e.code) {
                          case 'email-already-in-use':
                            msg = 'Este correo ya tiene una cuenta registrada.';
                            break;
                          case 'weak-password':
                            msg = 'Contraseña muy débil (mín. 6 caracteres).';
                            break;
                          default:
                            msg =
                                '[${e.code}] ${e.message ?? 'Error desconocido.'}';
                        }
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
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  _AgendaFilter _filter = _AgendaFilter.hoy;

  Future<void> _showRescheduleDialog(AppointmentModel appt) async {
    DateTime newDateTime = appt.fechaHora;
    int newDuration = appt.duracionMinutos;
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
                  subtitle: const Text('Fecha y hora'),
                  trailing: const Icon(Icons.edit_calendar, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: newDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(newDateTime),
                    );
                    if (t == null) return;
                    setDs(
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
                  onChanged: (v) => setDs(() => newDuration = v ?? 30),
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
          : 'Cita movida a Perdidas.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  // ─── Filtrado ────────────────────────────────────────────────────────────
  //
  // ✅ REGLA DEFINITIVA:
  //   • completadas  → SOLO en tab Completadas
  //   • canceladas   → SOLO en tab Canceladas
  //   • noAsistio    → SOLO en tab Perdidas
  //   • programadas viejas sin confirmar → tab Perdidas
  //   • programada/confirmada futuras → tab Activas (y Por fecha)

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
              a.estado != AppointmentStatus.reprogramada &&
              a.estado != AppointmentStatus.completada;
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
        // Solo y únicamente completadas
        return all
            .where((a) => a.estado == AppointmentStatus.completada)
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      case _AgendaFilter.perdidas:
        // Perdidas = noAsistio + programadas viejas, nunca completadas
        return all
            .where(
              (a) => _esPerdida(a) && a.estado != AppointmentStatus.completada,
            )
            .toList()
          ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      case _AgendaFilter.canceladas:
        // Solo y únicamente canceladas
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                ? () async => repo.updateAppointmentStatus(
                    appt.id,
                    AppointmentStatus.completada,
                  )
                : null,
            onReprogramar: () => _showRescheduleDialog(appt),
            onCancelar: () => _showCancelDialog(appt),
          ),
          _AgendaFilter.completadas => AppointmentCard(
            appointment: appt,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de citas'),
        actions: [
          // ✅ Botón para crear cuenta de paciente desde el admin
          IconButton(
            tooltip: 'Crear cuenta de paciente',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () =>
                AdminAppointmentsScreen.showCreatePatientAccountDialog(
                  context,
                  ref,
                ),
          ),
        ],
      ),
      body: Column(
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
                ButtonSegment(
                  value: _AgendaFilter.canceladas,
                  label: Text('Canceladas'),
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
                  Center(child: Text('No se pudo cargar agenda: $e')),
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

  Color _statusColor() => switch (appointment.estado) {
    AppointmentStatus.programada => OcgColors.bronze,
    AppointmentStatus.confirmada => const Color(0xFF2E7D32),
    AppointmentStatus.completada => const Color(0xFF1565C0),
    AppointmentStatus.cancelada => OcgColors.error,
    AppointmentStatus.noAsistio => const Color(0xFF6D4C41),
    AppointmentStatus.reprogramada => const Color(0xFF6A1B9A),
  };

  IconData _statusIcon() => switch (appointment.estado) {
    AppointmentStatus.programada => Icons.schedule,
    AppointmentStatus.confirmada => Icons.check_circle_outline,
    AppointmentStatus.completada => Icons.task_alt,
    AppointmentStatus.cancelada => Icons.cancel_outlined,
    AppointmentStatus.noAsistio => Icons.event_busy_outlined,
    AppointmentStatus.reprogramada => Icons.update,
  };

  String _statusLabel() => switch (appointment.estado) {
    AppointmentStatus.programada => 'Programada',
    AppointmentStatus.confirmada => 'Confirmada',
    AppointmentStatus.completada => 'Completada',
    AppointmentStatus.cancelada => 'Cancelada',
    AppointmentStatus.noAsistio => 'No asistió',
    AppointmentStatus.reprogramada => 'Reprogramada',
  };

  @override
  Widget build(BuildContext context) {
    final dt = appointment.fechaHora;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final sc = _statusColor();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.withOpacity(0.28)),
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
                  backgroundColor: sc.withOpacity(0.15),
                  child: Icon(_statusIcon(), color: sc, size: 20),
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
                      Text(
                        '${_labelTipo(appointment.tipo)} · '
                        '${appointment.duracionMinutos} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: OcgColors.ink.withOpacity(0.6),
                        ),
                      ),
                      // ✅ teléfono del paciente
                      if (appointment.patientPhone.isNotEmpty)
                        Text(
                          appointment.patientPhone,
                          style: TextStyle(
                            fontSize: 11,
                            color: OcgColors.bronze.withOpacity(0.8),
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
                        color: sc,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
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
