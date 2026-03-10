import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/providers/patients_provider.dart';
import '../data/models/appointment_model.dart';
import '../data/repositories/appointments_repository.dart';


final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return AppointmentsRepository(db);
});

class SelectedAppointmentsDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.keepAlive(); // ✅ AGREGA ESTA LÍNEA — evita que se destruya al cambiar de pantalla
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final selectedAppointmentsDateProvider = NotifierProvider<SelectedAppointmentsDateNotifier, DateTime>(
  SelectedAppointmentsDateNotifier.new,
);

final appointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  ref.keepAlive(); // ✅ AGREGA ESTA LÍNEA — el stream no se cancela al salir de la pantalla
  return ref.watch(appointmentsRepositoryProvider).watchAllAppointments();
});

final patientAppointmentsProvider = StreamProvider.family<List<AppointmentModel>, String>((ref, patientId) {
  return ref.watch(appointmentsRepositoryProvider).watchPatientAppointments(patientId);
});
