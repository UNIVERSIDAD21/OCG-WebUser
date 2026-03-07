import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  Stream<List<AppointmentModel>> watchAppointmentsByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _appointmentsRef
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fechaHora', isLessThan: Timestamp.fromDate(end))
        .where('estado', whereNotIn: [
          AppointmentStatus.cancelada.name,
          AppointmentStatus.noAsistio.name,
        ])
        .orderBy('fechaHora')
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  Future<String> createAppointment(AppointmentModel appointment) async {
    try {
      final conflictingQuery = _appointmentsRef
          .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(appointment.fechaHora))
          .where(
            'fechaHora',
            isLessThan: Timestamp.fromDate(
              appointment.fechaHora.add(Duration(minutes: appointment.duracionMinutos)),
            ),
          )
          .where('estado', whereNotIn: [
            AppointmentStatus.cancelada.name,
            AppointmentStatus.noAsistio.name,
            AppointmentStatus.reprogramada.name,
          ]);

      final conflicts = await conflictingQuery.get();
      if (conflicts.docs.isNotEmpty) {
        throw FirebaseException(
          plugin: 'appointments',
          code: 'SLOT_TAKEN',
          message: 'Este horario acaba de ser tomado. Por favor elige otro.',
        );
      }

      final ref = _appointmentsRef.doc();
      await ref.set(appointment.copyWith(id: ref.id).toJson());
      return ref.id;
    } catch (e) {
      if (e is FirebaseException && e.code == 'SLOT_TAKEN') {
        throw Exception('SLOT_TAKEN: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus newStatus) async {
    await _appointmentsRef.doc(appointmentId).update({
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rescheduleAppointment({
    required String originalId,
    required AppointmentModel newAppointment,
  }) async {
    final batch = _db.batch();
    final newRef = _appointmentsRef.doc();

    batch.update(_appointmentsRef.doc(originalId), {
      'estado': AppointmentStatus.reprogramada.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(newRef, newAppointment.copyWith(id: newRef.id).toJson());
    await batch.commit();
  }
}
