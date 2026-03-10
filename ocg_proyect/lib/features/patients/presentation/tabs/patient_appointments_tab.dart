import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../appointments/providers/appointments_provider.dart';
import '../../../dashboard/presentation/admin_appointments_screen.dart';
import '../../data/models/patient_model.dart';

class PatientAppointmentsTab extends ConsumerWidget {
  const PatientAppointmentsTab({super.key, required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(patient.id));

    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, __) => Center(
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
              subtitle: 'Sin citas registradas',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => AppointmentCard(
              appointment: appointments[index],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          preselectedPatient: patient,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}