import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

class AdminAppointmentsScreen extends ConsumerWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fecha activa: ${_fmtDate(selectedDate)}',
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
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('No se pudo cargar agenda: $error')),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return const Center(child: Text('No hay citas programadas en esta fecha.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (context, index) => _AppointmentAdminCard(appointment: appointments[index]),
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemCount: appointments.length,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAppointmentDialog(context, ref, selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
      ),
    );
  }

  static Future<void> _showCreateAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime baseDate,
  ) async {
    final patients = ref.read(filteredPatientsProvider);
    final patientNameCtrl = TextEditingController();
    final patientIdCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    AppointmentType type = AppointmentType.control;
    DateTime dateTime = baseDate.add(const Duration(hours: 10));

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
                  TextFormField(
                    controller: patientNameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre paciente'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: patientIdCtrl,
                    decoration: const InputDecoration(labelText: 'UID paciente'),
                  ),
                  const SizedBox(height: 8),
                  if (patients.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: patients.take(6).map((p) {
                          return ActionChip(
                            label: Text(p.nombre),
                            onPressed: () {
                              patientNameCtrl.text = p.nombre;
                              patientIdCtrl.text = p.id;
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha y hora'),
                    subtitle: Text(_fmtDateTime(dateTime)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: dateTime,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                      );
                      if (pickedDate == null) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dateTime),
                      );
                      if (pickedTime == null) return;

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
                  if (patientNameCtrl.text.trim().isEmpty || patientIdCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completa nombre y UID del paciente.')),
                    );
                    return;
                  }

                  try {
                    await ref.read(appointmentsRepositoryProvider).createAppointment(
                          AppointmentModel(
                            id: '',
                            patientId: patientIdCtrl.text.trim(),
                            patientName: patientNameCtrl.text.trim(),
                            tipo: type,
                            estado: AppointmentStatus.programada,
                            fechaHora: dateTime,
                            duracionMinutos: 30,
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

  static String _fmtDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _fmtDateTime(DateTime date) =>
      '${_fmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _AppointmentAdminCard extends ConsumerWidget {
  const _AppointmentAdminCard({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = appointment.fechaHora;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    Future<void> changeStatus(AppointmentStatus status) async {
      await ref.read(appointmentsRepositoryProvider).updateAppointmentStatus(appointment.id, status);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(time)),
              title: Text('${appointment.patientName} • ${appointment.tipo.name}'),
              subtitle: Text('Estado: ${appointment.estado.name} • ${appointment.duracionMinutos} min'),
              trailing: const Icon(Icons.chevron_right),
            ),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Confirmar'),
                  onPressed: () => changeStatus(AppointmentStatus.confirmada),
                ),
                ActionChip(
                  label: const Text('Completar'),
                  onPressed: () => changeStatus(AppointmentStatus.completada),
                ),
                ActionChip(
                  label: const Text('Cancelar'),
                  onPressed: () => changeStatus(AppointmentStatus.cancelada),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
