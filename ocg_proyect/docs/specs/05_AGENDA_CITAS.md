# 05 — Agenda de Citas [CORREGIDO v2.0]

## ⚠️ VERSIÓN CORREGIDA — Corrección CIT-01 aplicada

**CAMBIO CRÍTICO:** createAppointment ahora usa Firestore Transaction para prevenir race conditions. Dos pacientes NO pueden agendar el mismo horario simultáneamente.

---

## Lo que debes entregar al terminar este bloque

- [ ] AppointmentsCalendarScreen funcionando en web y app
- [ ] NewAppointmentScreen para el admin
- [ ] NewAppointmentScreen para el paciente (versión simplificada)
- [ ] AppointmentDetailScreen con cambio de estado
- [ ] MyAppointmentsScreen para el paciente
- [ ] appointments_repository.dart con Transaction en createAppointment (CIT-01)
- [ ] Cloud Function que programa el recordatorio FCM al crear la cita

---

## Reglas de negocio de las citas — memorízalas

1. El paciente puede agendar una cita **únicamente de tipo 'valoracion' o 'control'**. No puede agendar urgencias, instalaciones ni altas — eso lo hace el admin.
2. El paciente no puede agendar dos citas en el mismo día.
3. El admin puede crear citas de cualquier tipo.
4. Cuando se reprograma una cita, el estado de la cita original pasa a 'reprogramada' y se crea un documento nuevo. No se edita la fecha del documento original.
5. Una cita cancelada no puede volver a programarse — se crea una nueva.
6. El paciente puede cancelar una cita con mínimo 24 horas de anticipación. Si intenta cancelar con menos de 24 horas, mostrar advertencia y pedirle que llame al WhatsApp.

---

## appointments_repository.dart [CIT-01 CORREGIDO]

```dart
class AppointmentsRepository {
  final FirebaseFirestore _db;
  AppointmentsRepository(this._db);

  // Stream de citas de un día específico (para el calendario del admin)
  Stream<List<AppointmentModel>> watchAppointmentsByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection(FirestorePaths.appointments)
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fechaHora', isLessThan: Timestamp.fromDate(end))
        .where('estado', whereNotIn: ['cancelada', 'noAsistio'])
        .orderBy('fechaHora')
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  // Stream de citas de un paciente específico
  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _db
        .collection(FirestorePaths.appointments)
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  // ⚠️ CIT-01: Crear cita con Firestore Transaction
  // Previene race condition: dos pacientes viendo el mismo horario y creando cita simultáneamente
  Future<String> createAppointment(AppointmentModel appointment) async {
    try {
      final appointmentId = await _db.runTransaction<String>((transaction) async {
        // Query conflictos DENTRO de la transacción
        // Si otro paciente crea una cita en este bloque de tiempo mientras
        // ejecutamos esta query, la transacción se reintentar automáticamente
        final conflictingQuery = _db
            .collection(FirestorePaths.appointments)
            .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(appointment.fechaHora))
            .where('fechaHora', isLessThan: Timestamp.fromDate(
              appointment.fechaHora.add(Duration(minutes: appointment.duracionMinutos))
            ))
            .where('estado', whereNotIn: ['cancelada', 'noAsistio', 'reprogramada']);

        final conflicts = await transaction.get(conflictingQuery);

        if (conflicts.docs.isNotEmpty) {
          // Horario ya fue tomado — lanzar excepción especial
          throw FirebaseException(
            plugin: 'appointments',
            code: 'SLOT_TAKEN',
            message: 'Este horario acaba de ser tomado. Por favor elige otro.',
          );
        }

        // No hay conflicto — crear la cita dentro de la transacción
        final ref = _db.collection(FirestorePaths.appointments).doc();
        final appointmentWithId = appointment.copyWith(id: ref.id);
        transaction.set(ref, appointmentWithId.toJson());

        return ref.id;
      });

      return appointmentId;
    } catch (e) {
      // Capturar la excepción específica de horario tomado
      if (e is FirebaseException && e.code == 'SLOT_TAKEN') {
        throw Exception('SLOT_TAKEN: ${e.message}');
      }
      rethrow;
    }
  }

  // Actualizar estado de una cita
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    await _db
        .collection(FirestorePaths.appointments)
        .doc(appointmentId)
        .update({
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reprogramar cita (cambia estado de la original + crea nueva)
  Future<void> rescheduleAppointment({
    required String originalId,
    required AppointmentModel newAppointment,
  }) async {
    final batch = _db.batch();
    final newRef = _db.collection(FirestorePaths.appointments).doc();

    batch.update(
      _db.collection(FirestorePaths.appointments).doc(originalId),
      {
        'estado': AppointmentStatus.reprogramada.name,
        'updatedAt': FieldValue.serverTimestamp()
      },
    );

    batch.set(newRef, newAppointment.copyWith(id: newRef.id).toJson());
    await batch.commit();
  }
}
```

**Cómo manejar el error SLOT_TAKEN en la UI:**

```dart
try {
  final appointmentId = await _repository.createAppointment(appointment);
  // Mostrar éxito
} catch (e) {
  if (e.toString().contains('SLOT_TAKEN')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ese horario acaba de ser tomado por otro paciente. Elige otro.'),
        backgroundColor: Colors.red,
      ),
    );
    // Recargar disponibilidad
    ref.refresh(appointmentsForDateProvider);
  } else {
    // Otro error
    rethrow;
  }
}
```

---

## Resto del documento (NewAppointmentScreen, AppointmentsCalendarScreen, etc.)

Se mantiene igual al documento original. El único cambio es la implementación de createAppointment con Firestore Transaction.

