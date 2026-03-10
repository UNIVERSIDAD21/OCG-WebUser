import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  // ─── Streams ──────────────────────────────────────────────────────────────

  // FIX: whereNotIn en 'estado' removido de la query Firestore.
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
        .map((s) {
      return s.docs
          .map((d) => AppointmentModel.fromJson(d.data()))
          .where((a) =>
              a.estado != AppointmentStatus.cancelada &&
              a.estado != AppointmentStatus.noAsistio)
          .toList();
    });
  }

  Stream<List<AppointmentModel>> watchAllAppointments() {
    return _appointmentsRef
        .orderBy('fechaHora', descending: true)
        .snapshots()
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

  // ─── Crear cita (admin) ───────────────────────────────────────────────────
  //
  // Hace una query en TODA la colección de appointments para detectar conflictos
  // de horario. Solo funciona con permisos de admin porque las Firestore rules
  // no permiten al paciente leer appointments de otros pacientes.

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

  // ─── Crear cita (paciente) ────────────────────────────────────────────────
  //
  // Versión segura para pacientes:
  // - NO hace query global de conflictos (las Firestore rules lo bloquearían).
  //   La validación de mismo-día ya se hizo en el cliente antes de llegar aquí.
  // - Solo escribe el documento en la colección con el patientId del usuario,
  //   lo que las rules sí permiten: allow create if patientId == request.auth.uid.
  // - _updatePatientNextAppointment usa where('patientId', isEqualTo: patientId),
  //   que también está permitido por las rules para el propio paciente.

  Future<String> createAppointmentAsPatient(
      AppointmentModel appointment) async {
    try {
      final ref = _appointmentsRef.doc();
      await ref.set(appointment.copyWith(id: ref.id).toJson());
      await _updatePatientNextAppointment(appointment.patientId);
      return ref.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Actualizar estado ────────────────────────────────────────────────────

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

  // ─── Reprogramar ──────────────────────────────────────────────────────────

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

  // ─── Helper interno ───────────────────────────────────────────────────────

  Future<void> _updatePatientNextAppointment(String patientId) async {
    final snap = await _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .where('fechaHora', isGreaterThan: Timestamp.now())
        .orderBy('fechaHora')
        .get();

    final patientsRef =
        _db.collection(FirestorePaths.patients).doc(patientId);

    if (snap.docs.isEmpty) {
      await patientsRef.update({
        'proximaCita': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final nextAppt = AppointmentModel.fromJson(snap.docs.first.data());
    await patientsRef.update({
      'proximaCita': Timestamp.fromDate(nextAppt.fechaHora),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}