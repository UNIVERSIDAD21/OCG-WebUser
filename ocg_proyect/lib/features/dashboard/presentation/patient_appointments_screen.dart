import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

enum _PatientAppointmentsFilter { proximas, historial }

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends ConsumerState<PatientAppointmentsScreen> {
  _PatientAppointmentsFilter _filter = _PatientAppointmentsFilter.proximas;

  Future<void> _showNewAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    String patientId,
  ) async {
    final profile = await ref.read(patientByIdProvider(patientId).future);
    final patientNombre = (profile?.nombre ?? '').trim();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    if (patientNombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar tu perfil. Intenta de nuevo.'),
          backgroundColor: OcgColors.error,
        ),
      );
      return;
    }

    AppointmentType selectedType = AppointmentType.valoracion;
    DateTime selectedDateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text('Agendar cita'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppointmentType>(
                  initialValue: selectedType,
                  items: const [AppointmentType.valoracion, AppointmentType.control]
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.name)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedType = value ?? selectedType),
                  decoration: const InputDecoration(labelText: 'Tipo de cita'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha y hora'),
                  subtitle: Text(_fmtDateTime(selectedDateTime)),
                  trailing: const Icon(Icons.schedule, color: OcgColors.bronze),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDateTime,
                      firstDate: tomorrow,
                      lastDate: DateTime(2035),
                    );
                    if (pickedDate == null) return;
                    if (!dialogContext.mounted) return;

                    final pickedTime = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (pickedTime == null) return;

                    setState(() {
                      selectedDateTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  },
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Duración: 30 minutos',
                    style: TextStyle(color: OcgColors.ink),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OcgColors.bronze,
                  foregroundColor: OcgColors.ivory,
                ),
                onPressed: () async {
                  final appointments = ref.read(patientAppointmentsProvider(patientId)).asData?.value ??
                      const <AppointmentModel>[];
                  final hasSameDayAppointment = appointments.any((appointment) {
                    if (appointment.estado == AppointmentStatus.cancelada ||
                        appointment.estado == AppointmentStatus.noAsistio) {
                      return false;
                    }
                    return _isSameCalendarDay(appointment.fechaHora, selectedDateTime);
                  });

                  if (hasSameDayAppointment) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ya tienes una cita el ${_fmtDate(selectedDateTime)}. '
                          'No puedes agendar dos citas en el mismo día.',
                        ),
                        backgroundColor: OcgColors.error,
                      ),
                    );
                    return;
                  }

                  try {
                    await ref.read(appointmentsRepositoryProvider).createAppointment(
                          AppointmentModel(
                            id: '',
                            patientId: patientId,
                            patientName: patientNombre,
                            tipo: selectedType,
                            estado: AppointmentStatus.programada,
                            fechaHora: selectedDateTime,
                            duracionMinutos: 30,
                          ),
                        );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cita agendada correctamente.'),
                        backgroundColor: OcgColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    final message = e.toString().contains('SLOT_TAKEN')
                        ? 'Este horario acaba de ser tomado. Elige otro.'
                        : 'No se pudo agendar la cita. Intenta nuevamente.';
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(message), backgroundColor: OcgColors.error),
                    );
                  }
                },
                child: const Text('Agendar'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus citas.')),
      );
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.bronze,
        foregroundColor: OcgColors.ivory,
        icon: const Icon(Icons.add),
        label: const Text('Agendar cita'),
        onPressed: () => _showNewAppointmentDialog(context, ref, user.uid),
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
              error: (error, _) => Center(child: Text('No se pudo cargar citas: $error')),
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
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _fmtDateTime(DateTime date) =>
    '${_fmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile({required this.appointment});

  final AppointmentModel appointment;

  bool get _canShowCancelAction {
    return appointment.estado == AppointmentStatus.programada ||
        appointment.estado == AppointmentStatus.confirmada;
  }

  Future<void> _onCancelPressed(BuildContext context, WidgetRef ref) async {
    final horasRestantes = appointment.fechaHora.difference(DateTime.now()).inHours;
    final puedeCancelar = horasRestantes >= 24;

    if (puedeCancelar) {
      final confirmarCancelacion = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Cancelar esta cita?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: OcgColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancelar cita'),
            ),
          ],
        ),
      );

      if (confirmarCancelacion != true) return;

      await ref
          .read(appointmentsRepositoryProvider)
          .updateAppointmentStatus(appointment.id, AppointmentStatus.cancelada);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita cancelada correctamente.'),
          backgroundColor: OcgColors.success,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No puedes cancelar esta cita'),
        content: const Text(
          'Para cancelar con menos de 24 horas de anticipación, contáctanos directamente por WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Próximamente habilitaremos el contacto por WhatsApp.'),
                ),
              );
            },
            child: const Text('Contactar por WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        trailing: _canShowCancelAction
            ? TextButton.icon(
                onPressed: () => _onCancelPressed(context, ref),
                style: TextButton.styleFrom(foregroundColor: OcgColors.error),
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
