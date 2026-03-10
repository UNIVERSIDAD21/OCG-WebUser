import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/appointment_model.dart';
import '../data/repositories/appointments_repository.dart';
import '../../patients/providers/patients_provider.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(firestoreProvider));
});

// ─── Todas las citas (usado en AdminAppointmentsScreen) ───────────────────────

final appointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchAllAppointments();
});

// ─── Citas por paciente (usado en PatientAppointmentsScreen y PatientAppointmentsTab) ──

final patientAppointmentsProvider =
    StreamProvider.family<List<AppointmentModel>, String>((ref, patientId) {
  return ref
      .watch(appointmentsRepositoryProvider)
      .watchPatientAppointments(patientId);
});

// ─── Fecha seleccionada en la agenda ─────────────────────────────────────────

class _SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) => state = date;
}

final selectedAppointmentsDateProvider =
    NotifierProvider<_SelectedDateNotifier, DateTime>(
  _SelectedDateNotifier.new,
);