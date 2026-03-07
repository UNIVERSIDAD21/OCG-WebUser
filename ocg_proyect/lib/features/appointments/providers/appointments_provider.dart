import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/providers/patients_provider.dart';
import '../data/models/appointment_model.dart';
import '../data/repositories/appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return AppointmentsRepository(db);
});

final selectedAppointmentsDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final appointmentsByDateProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final date = ref.watch(selectedAppointmentsDateProvider);
  return ref.watch(appointmentsRepositoryProvider).watchAppointmentsByDate(date);
});

final patientAppointmentsProvider = StreamProvider.family<List<AppointmentModel>, String>((ref, patientId) {
  return ref.watch(appointmentsRepositoryProvider).watchPatientAppointments(patientId);
});
