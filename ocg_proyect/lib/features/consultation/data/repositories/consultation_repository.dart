import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation_model.dart';

class ConsultationRepository {
  ConsultationRepository(this._db);

  final FirebaseFirestore _db;

  // ─── Paths ────────────────────────────────────────────────────────────────

  String _consultationsPath(String patientId) =>
      'patients/$patientId/consultations';

  CollectionReference<Map<String, dynamic>> _consultationsRef(String patientId) =>
      _db.collection(_consultationsPath(patientId));

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<ConsultationModel>> watchPatientConsultations(String patientId) {
    return _consultationsRef(patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConsultationModel.fromJson(doc.data(), id: doc.id))
            .toList());
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<String> createConsultation(ConsultationModel consultation) async {
    final ref = _consultationsRef(consultation.patientId).doc();
    await ref.set(consultation.copyWith(id: ref.id).toJson());
    return ref.id;
  }

  Future<void> updateConsultation(
    String patientId,
    String consultationId,
    Map<String, dynamic> data,
  ) async {
    await _consultationsRef(patientId)
        .doc(consultationId)
        .update(data);
  }

  Future<ConsultationModel?> getConsultation(
    String patientId,
    String consultationId,
  ) async {
    final doc = await _consultationsRef(patientId).doc(consultationId).get();
    if (!doc.exists) return null;
    return ConsultationModel.fromJson(doc.data()!, id: doc.id);
  }

  // ─── Signature save ───────────────────────────────────────────────────────

  Future<void> saveSignature({
    required String patientId,
    required String consultationId,
    required String signatureUrl,
    required String actorId,
    required String actorName,
  }) async {
    final now = DateTime.now();
    final auditEntry = {
      'action': 'signature_added',
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.fromDate(now),
    };

    await _consultationsRef(patientId).doc(consultationId).update({
      'signatureUrl': signatureUrl,
      'signatureCapturedAt': Timestamp.fromDate(now),
      'status': 'completed',
      'auditTrail': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Complete consultation (with phase change) ────────────────────────────

  Future<void> completeConsultation({
    required String patientId,
    required String consultationId,
    required String clinicalNotes,
    required List<String> photos,
    ConsultationModel? phaseSnapshot,
    required String actorId,
    required String actorName,
    String? appointmentId,
  }) async {
    final now = DateTime.now();
    final auditEntry = {
      'action': 'completed',
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.fromDate(now),
      'details': phaseSnapshot != null && phaseSnapshot.phaseSnapshot != null
          ? 'Fase avanzada: ${phaseSnapshot.phaseSnapshot!.previousStage.name} → ${phaseSnapshot.phaseSnapshot!.currentStage.name}'
          : 'Consulta completada sin cambio de fase',
    };

    final updateData = {
      'clinicalNotes': clinicalNotes,
      'photos': photos,
      'status': 'completed',
      'auditTrail': FieldValue.arrayUnion([auditEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (phaseSnapshot != null && phaseSnapshot.phaseSnapshot != null) {
      updateData['phaseSnapshot'] = phaseSnapshot.phaseSnapshot!.toJson();
    }

    await _consultationsRef(patientId)
        .doc(consultationId)
        .update(updateData);
  }

  // ─── Add files to consultation ────────────────────────────────────────────

  Future<void> addFilesToConsultation({
    required String patientId,
    required String consultationId,
    required List<String> fileUrls,
  }) async {
    await _consultationsRef(patientId).doc(consultationId).update({
      'photos': FieldValue.arrayUnion(fileUrls),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
