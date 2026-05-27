import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/urgency_model.dart';

/// Capa de datos para CRUD de solicitudes de urgencia.
class UrgencyRepository {
  final _collection = FirebaseFirestore.instance.collection('urgencyRequests');

  /// Crear nueva solicitud (paciente).
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

  /// Stream de todas las urgencias (admin) — ordenadas por más reciente primero.
  Stream<List<UrgencyRequestModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  /// Stream de urgencias de un paciente específico.
  Stream<List<UrgencyRequestModel>> watchByPatient(String patientId) {
    return _collection
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  /// Urgencias activas (pendientes + en proceso) — para admin.
  Stream<List<UrgencyRequestModel>> watchActive() {
    return _collection
        .where('estado', whereIn: ['pendiente', 'enProceso'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  /// Actualizar estado (solo admin).
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

  /// Conteo de urgencias pendientes (para badge en admin).
  Stream<int> countPending() {
    return _collection
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Reprogramar una cita existente y dar su slot a la urgencia.
  /// SOLO admin puede ejecutar esto. Operación atómica via batch.
  Future<void> rescheduleAppointmentForUrgency({
    required String requestId,
    required String originalAppointmentId,
    required String originalPatientId,
    required DateTime newDateTimeForOriginal,
    required DateTime urgentSlotDateTime,
    required String urgentPatientId,
    required String urgentPatientName,
    required String urgentPatientPhone,
    required String adminId,
    int duracionMinutos = 30,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Reprogramar la cita original del otro paciente
    final originalApptRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(originalAppointmentId);
    batch.update(originalApptRef, {
      'estado': 'reprogramada',
      'fechaHora': Timestamp.fromDate(newDateTimeForOriginal),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Crear nueva cita de urgencia en el slot que se liberó
    final urgentApptRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc();
    final urgentApptData = {
      'id': urgentApptRef.id,
      'patientId': urgentPatientId,
      'patientName': urgentPatientName,
      'patientPhone': urgentPatientPhone,
      'tipo': 'urgencia',
      'estado': 'programada',
      'fechaHora': Timestamp.fromDate(urgentSlotDateTime),
      'duracionMinutos': duracionMinutos,
      'creadoPor': adminId,
      'notas': 'Cita de urgencia — slot liberado por reprogramación',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(urgentApptRef, urgentApptData);

    // Ejecutar atómicamente
    await batch.commit();

    // 3. Marcar urgencia como atendida vía reprogramación
    await updateStatus(
      requestId: requestId,
      newStatus: UrgencyStatus.atendida,
      appointmentId: urgentApptRef.id,
      reprogramadaFromId: originalAppointmentId,
    );
  }
}
