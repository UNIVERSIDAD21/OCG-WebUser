import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _db.collection(FirestorePaths.appointments);

  // ─── Streams ──────────────────────────────────────────────────────────────

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
              .where(
                (a) =>
                    a.estado != AppointmentStatus.cancelada &&
                    a.estado != AppointmentStatus.noAsistio,
              )
              .toList();
        });
  }

  // ✅ CAMBIO: watchAllAppointments ahora incluye citas canceladas
  //    para que la tab "Canceladas" del admin pueda mostrarlas.
  //    Cada filtro en AdminAppointmentsScreen excluye las que no corresponden.
  Stream<List<AppointmentModel>> watchAllAppointments() {
    return _appointmentsRef
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList(),
        );
  }

  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList(),
        );
  }

  // ─── Crear cita (admin) ───────────────────────────────────────────────────

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
              appointment.fechaHora.add(
                Duration(minutes: appointment.duracionMinutos),
              ),
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

  Future<String> createAppointmentAsPatient(
    AppointmentModel appointment,
  ) async {
    try {
      final ref = _appointmentsRef.doc();
      await ref.set(appointment.copyWith(id: ref.id).toJson());
      await _updatePatientNextAppointment(appointment.patientId);
      return ref.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Actualizar estado (admin) ────────────────────────────────────────────

  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    final appointmentSnapshot = await _appointmentsRef.doc(appointmentId).get();
    if (!appointmentSnapshot.exists) return;

    final patientId =
        (appointmentSnapshot.data()?['patientId'] ?? '') as String;

    await _appointmentsRef.doc(appointmentId).update({
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (newStatus == AppointmentStatus.cancelada ||
        newStatus == AppointmentStatus.reprogramada) {
      await _updatePatientNextAppointment(patientId);
    }
  }

  // ─── Cancelar cita (paciente) ─────────────────────────────────────────────
  //
  // ✅ NUEVO: versión segura para pacientes.
  //
  // Solo escribe los campos `estado` y `updatedAt`. Las Firestore rules
  // permiten este update porque:
  //   - resource.data.patientId == request.auth.uid  (es su propia cita)
  //   - request.resource.data.estado == 'cancelada'  (solo puede cancelar)
  //
  // No hace la query global de conflictos ni lee otros documentos —
  // las rules bloquearían esas operaciones para un paciente.

  Future<void> cancelAppointmentAsPatient(String appointmentId) async {
    await _appointmentsRef.doc(appointmentId).update({
      'estado': AppointmentStatus.cancelada.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Reprogramar cita ─────────────────────────────────────────────────────

  Future<void> rescheduleAppointment({
    required String originalId,
    required AppointmentModel newAppointment,
  }) async {
    // Marcar la cita original como reprogramada
    await _appointmentsRef.doc(originalId).update({
      'estado': AppointmentStatus.reprogramada.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Crear el nuevo documento
    final ref = _appointmentsRef.doc();
    await ref.set(newAppointment.copyWith(id: ref.id).toJson());
    await _updatePatientNextAppointment(newAppointment.patientId);
  }

  // ─── Helper: actualizar próxima cita del paciente ─────────────────────────

  Future<void> _updatePatientNextAppointment(String patientId) async {
    try {
      final now = DateTime.now();
      final upcoming = await _appointmentsRef
          .where('patientId', isEqualTo: patientId)
          .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('fechaHora')
          .limit(1)
          .get();

      final nextDate = upcoming.docs.isNotEmpty
          ? (upcoming.docs.first.data()['fechaHora'] as Timestamp).toDate()
          : null;

      await _db.collection(FirestorePaths.patients).doc(patientId).update({
        'proximaCita': nextDate != null ? Timestamp.fromDate(nextDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // No bloquear el flujo principal si falla la actualización de caché
    }
  }
}
