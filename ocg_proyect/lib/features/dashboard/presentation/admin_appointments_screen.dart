import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../patients/data/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

String _appointmentFmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _appointmentFmtDateTime(DateTime date) =>
    '${_appointmentFmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

enum _AgendaFilter { hoy, activas, completadas }

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  static Future<void> showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    DateTime? baseDate,
    PatientModel? preselectedPatient,
  }) async {
    final patients = ref.read(patientsStreamProvider).asData?.value ?? const <PatientModel>[];
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Nueva cita'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AppointmentType>(
                    initialValue: type,
                    items: AppointmentType.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v ?? type),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<PatientModel>(
                    displayStringForOption: (p) => p.nombre,
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return patients;
                      return patients.where((patient) {
                        return patient.nombre.toLowerCase().contains(query);
                      });
                    },
                    onSelected: (patient) {
                      setState(() {
                        selectedPatient = patient;
                        patientSearchCtrl.text = patient.nombre;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = patientSearchCtrl.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Buscar paciente',
                          hintText: 'Nombre completo',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          if (value.trim().isEmpty) {
                            setState(() => selectedPatient = null);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (selectedPatient != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(selectedPatient!.nombre),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            selectedPatient = null;
                            patientSearchCtrl.clear();
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    items: const [30, 45, 60, 90]
                        .map((minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => durationMinutes = value ?? 30),
                    decoration: const InputDecoration(labelText: 'Duración'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha y hora'),
                    subtitle: Text(_appointmentFmtDateTime(dateTime)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: dateTime,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                      );
                      if (pickedDate == null) return;
                      if (!context.mounted) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dateTime),
                      );
                      if (pickedTime == null) return;
                      if (!context.mounted) return;

                      setState(() {
                        dateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  if (selectedPatient == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona un paciente'),
                        backgroundColor: OcgColors.error,
                      ),
                    );
                    return;
                  }

                  try {
                    await ref.read(appointmentsRepositoryProvider).createAppointment(
                          AppointmentModel(
                            id: '',
                            patientId: selectedPatient!.id,
                            patientName: selectedPatient!.nombre,
                            tipo: type,
                            estado: AppointmentStatus.programada,
                            fechaHora: dateTime,
                            duracionMinutos: durationMinutes,
                            notas: notesCtrl.text.trim(),
                          ),
                        );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cita creada.')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo crear cita: $e')),
                    );
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtDate(DateTime date) => _appointmentFmtDate(date);

  @override
  ConsumerState<AdminAppointmentsScreen> createState() => _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends ConsumerState<AdminAppointmentsScreen> {
  _AgendaFilter _filter = _AgendaFilter.hoy;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAppointmentsDateProvider);
    final appointmentsAsync = ref.watch(appointmentsByDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de citas'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  color: OcgColors.bronze.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fecha activa: ${AdminAppointmentsScreen._fmtDate(selectedDate)}',
                    style: const TextStyle(
                      color: OcgColors.ivory,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      ref
                          .read(selectedAppointmentsDateProvider.notifier)
                          .setDate(DateTime(picked.year, picked.month, picked.day));
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: OcgColors.ivory),
                  label: const Text('Cambiar', style: TextStyle(color: OcgColors.ivory)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<_AgendaFilter>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return OcgColors.espresso;
                  }
                  return OcgColors.ivory;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return OcgColors.ivory;
                  }
                  return OcgColors.ink;
                }),
                side: const WidgetStatePropertyAll(BorderSide(color: OcgColors.bronze)),
              ),
              segments: const [
                ButtonSegment(value: _AgendaFilter.hoy, label: Text('Del día')),
                ButtonSegment(value: _AgendaFilter.activas, label: Text('Activas')),
                ButtonSegment(value: _AgendaFilter.completadas, label: Text('Completadas')),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('No se pudo cargar agenda: $error')),
              data: (appointments) {
                final filtered = _applyFilter(appointments);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No hay citas para el filtro seleccionado.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (context, index) => AppointmentCard(
                    appointment: filtered[index],
                    showActions: true,
                    onChangeStatus: (status) async {
                      try {
                        await ref
                            .read(appointmentsRepositoryProvider)
                            .updateAppointmentStatus(filtered[index].id, status);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo actualizar estado: $e')),
                        );
                      }
                    },
                  ),
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemCount: filtered.length,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(context, ref, baseDate: selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
      ),
    );
  }

  List<AppointmentModel> _applyFilter(List<AppointmentModel> appointments) {
    switch (_filter) {
      case _AgendaFilter.hoy:
        return appointments;
      case _AgendaFilter.activas:
        return appointments
            .where((a) => a.estado == AppointmentStatus.programada || a.estado == AppointmentStatus.confirmada)
            .toList();
      case _AgendaFilter.completadas:
        return appointments.where((a) => a.estado == AppointmentStatus.completada).toList();
    }
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.showActions = false,
    this.onChangeStatus,
  });

  final AppointmentModel appointment;
  final bool showActions;
  final Future<void> Function(AppointmentStatus status)? onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final dt = appointment.fechaHora;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: OcgColors.bronze.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: OcgColors.bronze.withValues(alpha: 0.18),
                child: Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              title: Text('${appointment.patientName} • ${appointment.tipo.name}'),
              subtitle: Text(
                'Estado: ${appointment.estado.name} • ${_appointmentFmtDateTime(appointment.fechaHora)} • ${appointment.duracionMinutos} min',
              ),
            ),
            if (showActions) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Confirmar'),
                    onPressed: onChangeStatus == null
                        ? null
                        : () => onChangeStatus!(AppointmentStatus.confirmada),
                  ),
                  ActionChip(
                    label: const Text('Completar'),
                    onPressed: onChangeStatus == null
                        ? null
                        : () => onChangeStatus!(AppointmentStatus.completada),
                  ),
                  ActionChip(
                    label: const Text('Cancelar'),
                    onPressed: onChangeStatus == null
                        ? null
                        : () => onChangeStatus!(AppointmentStatus.cancelada),
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
