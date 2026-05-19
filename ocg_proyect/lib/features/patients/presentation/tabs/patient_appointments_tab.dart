import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_loading_state.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../appointments/providers/appointments_provider.dart';
import '../../../dashboard/presentation/admin_appointments_screen.dart';
import '../../data/models/patient_model.dart';

class PatientAppointmentsTab extends ConsumerWidget {
  const PatientAppointmentsTab({
    super.key,
    required this.patient,
    this.scrollable = true,
  });

  final PatientModel patient;
  final bool scrollable;

  String _agendaLocationFor(AppointmentModel appointment) {
    final d = appointment.fechaHora;
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return Uri(
      path: RouteNames.adminAppointments,
      queryParameters: <String, String>{
        'date': date,
        'appointmentId': appointment.id,
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(
      patientAppointmentsProvider(patient.id),
    );

    return appointmentsAsync.when(
      loading: () => OcgLoadingState(),
      error: (error, _) => Center(
        child: Text(
          'No se pudo cargar citas: $error',
          style: const TextStyle(color: OcgColors.error),
          textAlign: TextAlign.center,
        ),
      ),
      data: (appointments) {
        if (appointments.isEmpty) {
          return const OcgEmptyState(
            icon: Icons.event_note_outlined,
            title: 'Sin citas registradas',
            subtitle: 'Este paciente no tiene citas aún.',
          );
        }

        if (!scrollable) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var index = 0; index < appointments.length; index++) ...[
                  AppointmentCard(
                    appointment: appointments[index],
                    showReminders: false,
                    onOpenInAgenda: () =>
                        context.go(_agendaLocationFor(appointments[index])),
                  ),
                  if (index != appointments.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => AppointmentCard(
            appointment: appointments[index],
            showReminders: false,
            onOpenInAgenda: () =>
                context.go(_agendaLocationFor(appointments[index])),
          ),
        );
      },
    );
  }
}
