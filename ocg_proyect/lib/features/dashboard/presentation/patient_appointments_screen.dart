import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../appointments/data/models/appointment_model.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver tus citas.')),
      );
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudo cargar citas: $error')),
        data: (appointments) {
          if (appointments.isEmpty) {
            return const Center(child: Text('No tienes citas registradas.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _AppointmentTile(appointment: appointments[index]),
          );
        },
      ),
    );
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
      child: ListTile(
        title: Text('${appointment.tipo.name} • $date $hour'),
        subtitle: Text('Estado: ${appointment.estado.name} • Duración: ${appointment.duracionMinutos} min'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
