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
        .orderBy('fechaHora')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromJson(doc.data()))
            .where((appointment) =>
                appointment.estado != AppointmentStatus.cancelada &&
                appointment.estado != AppointmentStatus.noAsistio)
            .toList());
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
          );

      final conflicts = await conflictingQuery.get();
      final hasActiveConflict = conflicts.docs
          .map((doc) => AppointmentModel.fromJson(doc.data()))
          .any((existing) =>
              existing.estado != AppointmentStatus.cancelada &&
              existing.estado != AppointmentStatus.noAsistio &&
              existing.estado != AppointmentStatus.reprogramada);

      if (hasActiveConflict) {
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
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
    Timestamp? fecha;

    while (fecha == null) {
      var query = _db
          .collection(FirestorePaths.appointments)
          .where('patientId', isEqualTo: patientId)
          .where('fechaHora', isGreaterThan: Timestamp.now())
          .orderBy('fechaHora')
          .limit(20);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final appointment = AppointmentModel.fromJson(doc.data());
        if (appointment.estado != AppointmentStatus.cancelada &&
            appointment.estado != AppointmentStatus.noAsistio) {
          final rawFecha = doc.data()['fechaHora'];
          if (rawFecha is Timestamp) {
            fecha = rawFecha;
          } else if (rawFecha is DateTime) {
            fecha = Timestamp.fromDate(rawFecha);
          }
          break;
        }
      }

      lastDoc = snap.docs.last;
    }

    await _db.collection(FirestorePaths.patients).doc(patientId).update({
      'proximaCita': fecha,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
