import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final FirebaseFirestore _db;

  static const List<String> _nextAppointmentStatuses = [
    'programada',
    'confirmada',
  ];

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  CollectionReference<Map<String, dynamic>> get _patientsRef =>
      _db.collection(FirestorePaths.patients);

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
      await _updatePatientNextAppointment(appointment.patientId);
      return ref.id;
    } catch (e) {
      if (e is FirebaseException && e.code == 'SLOT_TAKEN') {
        throw Exception('SLOT_TAKEN: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus newStatus) async {
    final appointmentSnapshot = await _appointmentsRef.doc(appointmentId).get();
    if (!appointmentSnapshot.exists) return;

    final patientId = (appointmentSnapshot.data()?['patientId'] ?? '').toString();

    await _appointmentsRef.doc(appointmentId).update({
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (patientId.isNotEmpty) {
      await _updatePatientNextAppointment(patientId);
    }
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

    await _updatePatientNextAppointment(newAppointment.patientId);
  }

  Future<void> _updatePatientNextAppointment(String patientId) async {
    final now = Timestamp.fromDate(DateTime.now());

    final nextAppointmentQuery = await _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .where('estado', whereIn: _nextAppointmentStatuses)
        .where('fechaHora', isGreaterThanOrEqualTo: now)
        .orderBy('fechaHora')
        .limit(1)
        .get();

    final rawNextDate =
        nextAppointmentQuery.docs.isNotEmpty ? nextAppointmentQuery.docs.first.data()['fechaHora'] : null;

    final Timestamp? nextTimestamp;
    if (rawNextDate is Timestamp) {
      nextTimestamp = rawNextDate;
    } else if (rawNextDate is DateTime) {
      nextTimestamp = Timestamp.fromDate(rawNextDate);
    } else {
      nextTimestamp = null;
    }

    await _patientsRef.doc(patientId).update({
      'proximaCita': nextTimestamp,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
