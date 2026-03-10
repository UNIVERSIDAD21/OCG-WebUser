import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_chip.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../appointments/data/models/appointment_model.dart';
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
        error: (error, _) => Center(
          child: Text(
            'No se pudo cargar citas: $error',
            style: const TextStyle(color: OcgColors.error),
            textAlign: TextAlign.center,
          ),
        ),
        data: (appointments) {
          if (appointments.isEmpty) {
            return OcgEmptyState(
              icon: Icons.event_note_outlined,
              title: 'Sin citas registradas',
              subtitle: 'Este paciente no tiene citas aún.',
              ctaLabel: 'Crear cita',
              onCta: () => AdminAppointmentsScreen.showCreateDialog(
                context,
                ref,
                baseDate: DateTime.now(),
                preselectedPatient: patient,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PatientAppointmentAdminCard(
              appointment: appointments[index],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        onPressed: () => AdminAppointmentsScreen.showCreateDialog(
          context,
          ref,
          baseDate: DateTime.now(),
          preselectedPatient: patient,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Crear cita'),
      ),
    );
  }
}

class _PatientAppointmentAdminCard extends ConsumerWidget {
  const _PatientAppointmentAdminCard({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = appointment.fechaHora;

    Future<void> changeStatus(AppointmentStatus status) async {
      await ref.read(appointmentsRepositoryProvider).updateAppointmentStatus(appointment.id, status);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: OcgColors.bronze.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmtDateTime(dt),
              style: const TextStyle(
                color: OcgColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OcgChip(label: appointment.tipo.name),
                OcgChip(label: '${appointment.duracionMinutos} min'),
                OcgChip(label: appointment.estado.name),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: OcgColors.mist,
                  label: const Text('Confirmar', style: TextStyle(color: OcgColors.ink)),
                  onPressed: () => changeStatus(AppointmentStatus.confirmada),
                ),
                ActionChip(
                  backgroundColor: OcgColors.mist,
                  label: const Text('Completar', style: TextStyle(color: OcgColors.ink)),
                  onPressed: () => changeStatus(AppointmentStatus.completada),
                ),
                ActionChip(
                  backgroundColor: OcgColors.error.withValues(alpha: 0.12),
                  label: const Text('Cancelar', style: TextStyle(color: OcgColors.error)),
                  onPressed: () => changeStatus(AppointmentStatus.cancelada),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
