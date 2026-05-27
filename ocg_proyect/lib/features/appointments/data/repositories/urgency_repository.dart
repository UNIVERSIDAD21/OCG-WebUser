import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../patients/data/models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/urgency_model.dart';

class UrgencyRescheduleResult {
  const UrgencyRescheduleResult({
    required this.urgentAppointmentId,
    required this.movedAppointmentId,
    required this.originalAppointmentId,
  });

  final String urgentAppointmentId;
  final String movedAppointmentId;
  final String originalAppointmentId;
}

/// Capa de datos para solicitudes de urgencia.
class UrgencyRepository {
  UrgencyRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.urgencyRequests);

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection(FirestorePaths.appointments);

  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection(FirestorePaths.patients);

  Future<UrgencyRequestModel> create({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required String descripcion,
  }) async {
    final docRef = _collection.doc();
    final model = UrgencyRequestModel(
      id: docRef.id,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      descripcion: descripcion,
      estado: UrgencyStatus.pendiente,
      createdAt: DateTime.now(),
    );
    await docRef.set(model.toJson());
    return model;
  }

  Stream<List<UrgencyRequestModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  Stream<List<UrgencyRequestModel>> watchByPatient(String patientId) {
    return _collection
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  Stream<List<UrgencyRequestModel>> watchActive() {
    return _collection
        .where(
          'estado',
          whereIn: [UrgencyStatus.pendiente.name, UrgencyStatus.enProceso.name],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  Future<void> updateStatus({
    required String requestId,
    required UrgencyStatus newStatus,
    String? adminNotes,
    String? appointmentId,
    String? reprogramadaFromId,
  }) async {
    final data = <String, dynamic>{
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNotes != null) data['adminNotes'] = adminNotes;
    if (appointmentId != null) data['appointmentId'] = appointmentId;
    if (reprogramadaFromId != null) {
      data['reprogramadaFromId'] = reprogramadaFromId;
    }
    await _collection.doc(requestId).update(data);
  }

  Stream<int> countPending() {
    return _collection
        .where('estado', isEqualTo: UrgencyStatus.pendiente.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String> createAppointmentFromUrgency({
    required UrgencyRequestModel request,
    required AppointmentModel appointment,
    required String adminId,
    String? adminNotes,
  }) async {
    final appointmentRef = _appointments.doc();
    final requestRef = _collection.doc(request.id);
    final patientRef = _patients.doc(request.patientId);
    final now = DateTime.now();
    final urgencyAppointment = appointment.copyWith(
      id: appointmentRef.id,
      patientId: request.patientId,
      patientName: request.patientName,
      patientPhone: request.patientPhone,
      tipo: AppointmentType.urgencia,
      estado: AppointmentStatus.programada,
      creadoPor: adminId,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(appointmentRef, {
      ...urgencyAppointment.toJson(),
      'createdByRole': 'admin',
      'createdBy': adminId,
      'lastActionByRole': 'admin',
      'lastActionBy': adminId,
      'updatedByRole': 'admin',
      'updatedBy': adminId,
      'urgencyRequestId': request.id,
    });
    final requestUpdate = <String, dynamic>{
      'estado': UrgencyStatus.atendida.name,
      'appointmentId': appointmentRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNotes != null) requestUpdate['adminNotes'] = adminNotes;
    batch.update(requestRef, requestUpdate);
    batch.update(patientRef, {
      'proximaCita': Timestamp.fromDate(appointment.fechaHora),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return appointmentRef.id;
  }

  Future<UrgencyRescheduleResult> rescheduleAppointmentForUrgency({
    required UrgencyRequestModel request,
    required AppointmentModel originalAppointment,
    required DateTime newDateTimeForOriginal,
    required String adminId,
    String? adminNotes,
  }) async {
    final originalRef = _appointments.doc(originalAppointment.id);
    final movedRef = _appointments.doc();
    final urgentRef = _appointments.doc();
    final requestRef = _collection.doc(request.id);
    final originalPatientRef = _patients.doc(originalAppointment.patientId);
    final urgentPatientRef = _patients.doc(request.patientId);
    final urgentSlotDateTime = originalAppointment.fechaHora;
    final now = DateTime.now();

    await _db.runTransaction((transaction) async {
      final originalSnapshot = await transaction.get(originalRef);
      if (!originalSnapshot.exists || originalSnapshot.data() == null) {
        throw StateError('La cita original ya no existe.');
      }

      final currentOriginal = AppointmentModel.fromJson({
        ...originalSnapshot.data()!,
        'id': originalAppointment.id,
      });
      if (currentOriginal.estado != AppointmentStatus.programada &&
          currentOriginal.estado != AppointmentStatus.confirmada) {
        throw StateError(
          'Solo se pueden reprogramar citas programadas o confirmadas.',
        );
      }

      final movedAppointment = currentOriginal.copyWith(
        id: movedRef.id,
        fechaHora: newDateTimeForOriginal,
        estado: AppointmentStatus.programada,
        createdAt: now,
        updatedAt: now,
        notas: [
          if ((currentOriginal.notas ?? '').trim().isNotEmpty)
            currentOriginal.notas!.trim(),
          'Cita reprogramada por gestion de urgencia.',
        ].join('\n'),
      );
      final urgentAppointment = AppointmentModel(
        id: urgentRef.id,
        patientId: request.patientId,
        patientName: request.patientName,
        patientPhone: request.patientPhone,
        tipo: AppointmentType.urgencia,
        estado: AppointmentStatus.programada,
        fechaHora: urgentSlotDateTime,
        duracionMinutos: currentOriginal.duracionMinutos,
        creadoPor: adminId,
        notas: 'Cita de urgencia en slot liberado por reprogramacion.',
        createdAt: now,
        updatedAt: now,
      );

      transaction.update(originalRef, {
        'estado': AppointmentStatus.reprogramada.name,
        'fechaHora': Timestamp.fromDate(newDateTimeForOriginal),
        'rescheduledToAppointmentId': movedRef.id,
        'rescheduledTo': Timestamp.fromDate(newDateTimeForOriginal),
        'lastActionByRole': 'admin',
        'lastActionBy': adminId,
        'updatedByRole': 'admin',
        'updatedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movedRef, {
        ...movedAppointment.toJson(),
        'createdByRole': 'admin',
        'createdBy': adminId,
        'lastActionByRole': 'admin',
        'lastActionBy': adminId,
        'updatedByRole': 'admin',
        'updatedBy': adminId,
        'rescheduledFromId': originalAppointment.id,
      });
      transaction.set(urgentRef, {
        ...urgentAppointment.toJson(),
        'createdByRole': 'admin',
        'createdBy': adminId,
        'lastActionByRole': 'admin',
        'lastActionBy': adminId,
        'updatedByRole': 'admin',
        'updatedBy': adminId,
        'urgencyRequestId': request.id,
        'reprogramadaFromId': originalAppointment.id,
      });
      final requestUpdate = <String, dynamic>{
        'estado': UrgencyStatus.atendida.name,
        'appointmentId': urgentRef.id,
        'reprogramadaFromId': originalAppointment.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (adminNotes != null) requestUpdate['adminNotes'] = adminNotes;
      transaction.update(requestRef, requestUpdate);
      transaction.update(originalPatientRef, {
        'proximaCita': Timestamp.fromDate(newDateTimeForOriginal),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(urgentPatientRef, {
        'proximaCita': Timestamp.fromDate(urgentSlotDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return UrgencyRescheduleResult(
      urgentAppointmentId: urgentRef.id,
      movedAppointmentId: movedRef.id,
      originalAppointmentId: originalAppointment.id,
    );
  }

  Future<int> cleanupOldUrgencies({int daysAgo = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysAgo));
    final snapshot = await _collection
        .where(
          'estado',
          whereIn: [
            UrgencyStatus.atendida.name,
            UrgencyStatus.rechazada.name,
            UrgencyStatus.reprogramada.name,
          ],
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'archived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  List<UrgencyRequestModel> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .where((doc) => doc.data()['archived'] != true)
        .map(
          (doc) => UrgencyRequestModel.fromJson({...doc.data(), 'id': doc.id}),
        )
        .toList();
  }

  PatientModel patientFromUrgency(UrgencyRequestModel request) {
    return PatientModel.fromJson({
      'id': request.patientId,
      'uid': request.patientId,
      'nombre': request.patientName,
      'telefono': request.patientPhone,
      'etapaActual': TreatmentStage.valoracionInicial.name,
      'fechaInicio': Timestamp.fromDate(DateTime.now()),
      'notasClinicas': '',
      'totalTratamiento': 0,
      'saldoPendiente': 0,
    });
  }
}
