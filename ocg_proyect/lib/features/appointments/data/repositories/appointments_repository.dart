import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../domain/appointments_business_rules.dart';
import '../models/appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db, [FirebaseFunctions? functions])
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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
                    a.estado != AppointmentStatus.noAsistio &&
                    a.estado != AppointmentStatus.reprogramada,
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
        .asyncMap((s) async {
          final items = _dedupeAppointments(
            s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList(),
          );
          final reconciled = await _reconcileNoShowStatuses(items);
          return reconciled;
        });
  }

  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _appointmentsRef
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .asyncMap((s) async {
          final items = _dedupeAppointments(
            s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList(),
          );
          final reconciled = await _reconcileNoShowStatuses(items);
          return reconciled;
        });
  }

  // ─── Crear cita (admin) ───────────────────────────────────────────────────

  Future<String> createAppointment(AppointmentModel appointment) async {
    // Safety-net arquitectónico: si por error de UI/ruteo llega un intento
    // de agenda de paciente por la ruta "admin" (write directo), lo redirigimos
    // al flujo oficial vía Cloud Function para evitar PERMISSION_DENIED.
    if (appointment.creadoPor == appointment.patientId) {
      return createAppointmentAsPatient(appointment);
    }

    try {
      final workingHoursError = AppointmentsBusinessRules.validateWithinWorkingHours(
        start: appointment.fechaHora,
        durationMinutes: appointment.duracionMinutos,
      );
      if (workingHoursError != null) {
        throw FirebaseException(
          plugin: 'appointments',
          code: 'OUTSIDE_WORKING_HOURS',
          message: workingHoursError,
        );
      }

      final hasConflict = await _hasTimeConflict(
        start: appointment.fechaHora,
        durationMinutes: appointment.duracionMinutos,
      );

      if (hasConflict) {
        throw FirebaseException(
          plugin: 'appointments',
          code: 'SLOT_TAKEN',
          message: 'Ese horario ya está ocupado. Por favor elige otro.',
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
    final existingSameSlot = await _findExistingSameSlotForPatient(appointment);
    if (existingSameSlot != null) {
      return existingSameSlot;
    }

    final callable = _functions.httpsCallable('reserveAppointment');
    final date =
        '${appointment.fechaHora.year.toString().padLeft(4, '0')}-'
        '${appointment.fechaHora.month.toString().padLeft(2, '0')}-'
        '${appointment.fechaHora.day.toString().padLeft(2, '0')}';
    final time =
        '${appointment.fechaHora.hour.toString().padLeft(2, '0')}:'
        '${appointment.fechaHora.minute.toString().padLeft(2, '0')}';

    try {
      final result = await callable.call(<String, dynamic>{
        'date': date,
        'time': time,
        'durationMinutes': appointment.duracionMinutos,
        'type': appointment.tipo.name,
        'notes': appointment.notas,
      });
      final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
      return (data['appointmentId'] ?? '').toString();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo reservar la cita.');
    }
  }

  // ─── Actualizar estado (admin) ────────────────────────────────────────────

  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus, {
    String actorRole = 'admin',
    String? actorUserId,
    String? updatedByRole,
    String? updatedBy,
  }) async {
    final appointmentSnapshot = await _appointmentsRef.doc(appointmentId).get();
    if (!appointmentSnapshot.exists) return;

    final patientId =
        (appointmentSnapshot.data()?['patientId'] ?? '') as String;

    await _appointmentsRef.doc(appointmentId).update({
      'estado': newStatus.name,
      'lastActionByRole': actorRole,
      'lastActionBy': actorUserId,
      'updatedByRole': updatedByRole ?? actorRole,
      'updatedBy': updatedBy ?? actorUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (newStatus == AppointmentStatus.cancelada ||
        newStatus == AppointmentStatus.reprogramada ||
        newStatus == AppointmentStatus.confirmada ||
        newStatus == AppointmentStatus.programada) {
      await _updatePatientNextAppointment(patientId);
    }
  }

  // ─── Cancelar cita (paciente) ─────────────────────────────────────────────
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
    final workingHoursError = AppointmentsBusinessRules.validateWithinWorkingHours(
      start: newAppointment.fechaHora,
      durationMinutes: newAppointment.duracionMinutos,
    );
    if (workingHoursError != null) {
      throw FirebaseException(
        plugin: 'appointments',
        code: 'OUTSIDE_WORKING_HOURS',
        message: workingHoursError,
      );
    }

    final hasConflict = await _hasTimeConflict(
      start: newAppointment.fechaHora,
      durationMinutes: newAppointment.duracionMinutos,
      excludeAppointmentId: originalId,
    );

    if (hasConflict) {
      throw FirebaseException(
        plugin: 'appointments',
        code: 'SLOT_TAKEN',
        message: 'Ese horario ya está ocupado. Por favor elige otro.',
      );
    }

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

  // ─── Validación de solapes de horario ─────────────────────────────────────

  Future<bool> _hasTimeConflict({
    required DateTime start,
    required int durationMinutes,
    String? excludeAppointmentId,
  }) async {
    final dayStart = DateTime(start.year, start.month, start.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final newEnd = start.add(Duration(minutes: durationMinutes));

    final snapshot = await _appointmentsRef
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('fechaHora', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    for (final doc in snapshot.docs) {
      final appt = AppointmentModel.fromJson(doc.data());

      if (excludeAppointmentId != null && appt.id == excludeAppointmentId) {
        continue;
      }

      if (appt.estado == AppointmentStatus.cancelada ||
          appt.estado == AppointmentStatus.noAsistio ||
          appt.estado == AppointmentStatus.reprogramada) {
        continue;
      }

      final existingStart = appt.fechaHora;
      final existingEnd = existingStart.add(
        Duration(
          minutes:
              appt.duracionMinutos +
              AppointmentsBusinessRules.bufferMinutesBetweenAppointments,
        ),
      );
      final overlaps = start.isBefore(existingEnd) && existingStart.isBefore(newEnd);

      if (overlaps) return true;
    }

    return false;
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

  Future<List<AppointmentModel>> _reconcileNoShowStatuses(
    List<AppointmentModel> items,
  ) async {
    final now = DateTime.now();
    final toNoShow = items
        .where((a) => AppointmentsBusinessRules.shouldMarkAsNoShow(a, now: now))
        .toList();

    if (toNoShow.isEmpty) return items;

    try {
      final callable = _functions.httpsCallable('reconcileNoShowAppointments');
      await callable.call(<String, dynamic>{
        'appointmentIds': toNoShow.map((e) => e.id).toList(),
      });
    } catch (_) {
      // Si la función no está desplegada o falla, mantenemos consistencia visual
      // en cliente sin romper flujo ni permisos.
    }

    final noShowIds = toNoShow.map((e) => e.id).toSet();
    return items
        .map(
          (a) => noShowIds.contains(a.id)
              ? a.copyWith(estado: AppointmentStatus.noAsistio)
              : a,
        )
        .toList();
  }

  List<AppointmentModel> _dedupeAppointments(List<AppointmentModel> items) {
    final map = <String, AppointmentModel>{};

    for (final a in items) {
      final key = a.id.trim().isNotEmpty
          ? 'id:${a.id.trim()}'
          : 'fp:${a.patientId}|${a.fechaHora.toIso8601String()}|${a.tipo.name}|${a.estado.name}';

      final existing = map[key];
      if (existing == null) {
        map[key] = a;
      } else {
        final currentTs = a.createdAt ?? a.updatedAt ?? a.fechaHora;
        final existingTs = existing.createdAt ?? existing.updatedAt ?? existing.fechaHora;
        if (currentTs.isAfter(existingTs)) {
          map[key] = a;
        }
      }
    }

    final deduped = map.values.toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    return deduped;
  }

  Future<String?> _findExistingSameSlotForPatient(AppointmentModel appointment) async {
    final start = appointment.fechaHora;
    final end = start.add(Duration(minutes: appointment.duracionMinutos));

    final sameDayStart = DateTime(start.year, start.month, start.day);
    final sameDayEnd = sameDayStart.add(const Duration(days: 1));

    final snapshot = await _appointmentsRef
        .where('patientId', isEqualTo: appointment.patientId)
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(sameDayStart))
        .where('fechaHora', isLessThan: Timestamp.fromDate(sameDayEnd))
        .get();

    for (final doc in snapshot.docs) {
      final current = AppointmentModel.fromJson(doc.data());

      if (current.estado == AppointmentStatus.cancelada ||
          current.estado == AppointmentStatus.noAsistio ||
          current.estado == AppointmentStatus.reprogramada) {
        continue;
      }

      final currentStart = current.fechaHora;
      final currentEnd = currentStart.add(Duration(minutes: current.duracionMinutos));
      final overlaps = currentStart.isBefore(end) && start.isBefore(currentEnd);

      if (overlaps) {
        return current.id.isNotEmpty ? current.id : doc.id;
      }
    }

    return null;
  }
}
