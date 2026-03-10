import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  // FIX #1: whereNotIn en 'estado' removido de la query Firestore.
  // Combinarlo con el rango en 'fechaHora' requiere índice compuesto.
  // El filtro se aplica en Dart después de recibir los documentos.
  Stream<List<AppointmentModel>> watchAppointmentsByDate(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));

  return _appointmentsRef
      .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('fechaHora', isLessThan: Timestamp.fromDate(end))
      .orderBy('fechaHora')
      .snapshots()
      .handleError((error) {
        throw error;
      })
      .map((s) {
        return s.docs
            .map((d) => AppointmentModel.fromJson(d.data()))
            .where((a) =>
                a.estado != AppointmentStatus.cancelada &&
                a.estado != AppointmentStatus.noAsistio)
            .toList();
      });
}

  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  // FIX #2: whereNotIn en 'estado' removido de la query de conflictos.
  // El filtro se aplica en Dart.
  Future<String> createAppointment(AppointmentModel appointment) async {
    try {
      final snapshot = await _appointmentsRef
          .where(
            'fechaHora',
            isGreaterThanOrEqualTo: Timestamp.fromDate(appointment.fechaHora),
          )
          .where(
            'fechaHora',
            isLessThan: Timestamp.fromDate(
              appointment.fechaHora
                  .add(Duration(minutes: appointment.duracionMinutos)),
            ),
          )
          .get();

      final hasConflict = snapshot.docs.any((doc) {
        final model = AppointmentModel.fromJson(doc.data());
        return model.estado != AppointmentStatus.cancelada &&
            model.estado != AppointmentStatus.noAsistio &&
            model.estado != AppointmentStatus.reprogramada;
      });

      if (hasConflict) {
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
        throw Exception('Error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    final appointmentSnapshot =
        await _appointmentsRef.doc(appointmentId).get();
    if (!appointmentSnapshot.exists) return;

    final patientId =
        (appointmentSnapshot.data()?['patientId'] ?? '').toString();

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
    final snap = await _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .where('fechaHora', isGreaterThan: Timestamp.now())
        .orderBy('fechaHora')
        .get();

    Map<String, dynamic>? nextData;
    for (final doc in snap.docs) {
      final model = AppointmentModel.fromJson(doc.data());
      if (model.estado != AppointmentStatus.cancelada &&
          model.estado != AppointmentStatus.noAsistio &&
          model.estado != AppointmentStatus.reprogramada) {
        nextData = doc.data();
        break;
      }
    }

    await _db.collection(FirestorePaths.patients).doc(patientId).update({
      'proximaCita': nextData?['fechaHora'],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}