import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';

enum _PatientAppointmentsFilter { proximas, historial }

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends ConsumerState<PatientAppointmentsScreen> {
  _PatientAppointmentsFilter _filter = _PatientAppointmentsFilter.proximas;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus citas.')),
      );
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.uid));
    final patientProfileAsync = ref.watch(patientByIdProvider(user.uid));
    final patientName = patientProfileAsync.asData?.value?.nombre ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
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
            ),
            child: const Text(
              'Consulta tus próximas citas y tu historial de asistencia.',
              style: TextStyle(color: OcgColors.ivory, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<_PatientAppointmentsFilter>(
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
                ButtonSegment(value: _PatientAppointmentsFilter.proximas, label: Text('Próximas')),
                ButtonSegment(value: _PatientAppointmentsFilter.historial, label: Text('Historial')),
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
              error: (error, _) => Center(
                child: Text(
                  'No se pudo cargar citas: $error',
                  style: const TextStyle(color: OcgColors.error),
                ),
              ),
              data: (appointments) {
                final filtered = _applyFilter(appointments);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No tienes citas para este filtro.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AppointmentTile(appointment: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => _showNewAppointmentDialog(
          context,
          ref,
          user.uid,
          patientName,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Agendar cita'),
      ),
    );
  }

  List<AppointmentModel> _applyFilter(List<AppointmentModel> appointments) {
    final now = DateTime.now();
    switch (_filter) {
      case _PatientAppointmentsFilter.proximas:
        return appointments.where((a) => a.fechaHora.isAfter(now)).toList();
      case _PatientAppointmentsFilter.historial:
        return appointments.where((a) => !a.fechaHora.isAfter(now)).toList();
    }
  }

  static Future<void> _showNewAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    String patientName,
  ) async {
    AppointmentType type = AppointmentType.valoracion;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    DateTime dateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agendar cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppointmentType>(
                  initialValue: type,
                  items: const [AppointmentType.valoracion, AppointmentType.control]
                      .map((allowedType) => DropdownMenuItem<AppointmentType>(
                            value: allowedType,
                            child: Text(allowedType.name),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => type = value ?? AppointmentType.valoracion),
                  decoration: const InputDecoration(labelText: 'Tipo de cita'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha y hora'),
                  subtitle: Text(_fmtDateTime(dateTime)),
                  trailing: const Icon(Icons.schedule, color: OcgColors.espresso),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: dateTime,
                      firstDate: tomorrow,
                      lastDate: tomorrow.add(const Duration(days: 90)),
                    );
                    if (pickedDate == null) return;
                    if (!context.mounted) return;

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
                      errorMsg = null;
                    });
                  },
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(color: OcgColors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final profileName = patientName.trim().isNotEmpty
                    ? patientName.trim()
                    : ref.read(patientByIdProvider(patientId)).asData?.value?.nombre.trim() ?? '';

                if (profileName.isEmpty) {
                  setState(() => errorMsg = 'No se pudo cargar tu perfil. Intenta recargar la app.');
                  return;
                }

                final existingAppointments =
                    ref.read(patientAppointmentsProvider(patientId)).asData?.value ?? const <AppointmentModel>[];

                final hasSameDayAppointment = existingAppointments.any((appointment) {
                  final appointmentDate = appointment.fechaHora;
                  return appointmentDate.year == dateTime.year &&
                      appointmentDate.month == dateTime.month &&
                      appointmentDate.day == dateTime.day &&
                      appointment.estado != AppointmentStatus.cancelada &&
                      appointment.estado != AppointmentStatus.noAsistio;
                });

                if (hasSameDayAppointment) {
                  setState(
                    () => errorMsg =
                        'Ya tienes una cita el ${_fmtDate(dateTime)}. No puedes agendar dos citas en el mismo día.',
                  );
                  return;
                }

                try {
                  await ref.read(appointmentsRepositoryProvider).createAppointment(
                        AppointmentModel(
                          id: '',
                          patientId: patientId,
                          patientName: profileName,
                          tipo: type,
                          estado: AppointmentStatus.programada,
                          fechaHora: dateTime,
                          duracionMinutos: 30,
                          notas: '',
                        ),
                      );

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cita agendada exitosamente.')),
                  );
                } catch (e) {
                  setState(() {
                    if (e.toString().contains('SLOT_TAKEN')) {
                      errorMsg = 'Este horario acaba de ser tomado. Elige otro.';
                    } else {
                      errorMsg = 'No se pudo agendar la cita. Intenta de nuevo.';
                    }
                  });
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _fmtDateTime(DateTime dt) {
    return '${_fmtDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final dt = appointment.fechaHora;
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final hour = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: OcgColors.bronze.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: OcgColors.bronze.withValues(alpha: 0.18),
          child: const Icon(Icons.event_note),
        ),
        title: Text('${appointment.tipo.name} • $date $hour'),
        subtitle: Text('Estado: ${appointment.estado.name} • Duración: ${appointment.duracionMinutos} min'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
