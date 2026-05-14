import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../clinical_files/data/models/clinical_file_model.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../treatment/data/models/stage_history_entry.dart';
import '../models/consultation_model.dart';

class ConsultationRepository {
  ConsultationRepository(this._db);

  final FirebaseFirestore _db;

  // ─── Paths ────────────────────────────────────────────────────────────────

  String _consultationsPath(String patientId) =>
      'patients/$patientId/consultations';

  CollectionReference<Map<String, dynamic>> _consultationsRef(
    String patientId,
  ) => _db.collection(_consultationsPath(patientId));

  DocumentReference<Map<String, dynamic>> _consultationRef(
    String patientId,
    String consultationId,
  ) => _consultationsRef(patientId).doc(consultationId);

  String newConsultationId(String patientId) =>
      _consultationsRef(patientId).doc().id;

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<ConsultationModel>> watchPatientConsultations(String patientId) {
    return _consultationsRef(patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConsultationModel.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<String> createConsultation(ConsultationModel consultation) async {
    final ref = _consultationsRef(consultation.patientId).doc();
    await ref.set(consultation.copyWith(id: ref.id).toJson());
    return ref.id;
  }

  Future<void> saveCompletedConsultation({
    required ConsultationModel consultation,
    required List<ClinicalFileModel> clinicalFiles,
    required String appointmentId,
    required TreatmentStage currentStage,
    required TreatmentStage resultingStage,
    required String stageSummary,
    required String actorId,
    required bool advancePhase,
    String? treatmentId,
    bool treatmentIsPrimary = true,
    String? stageReason,
    String? nextStagePlan,
    String? attachmentsSummary,
  }) async {
    final consultationId = consultation.id.trim();
    if (consultationId.isEmpty) {
      throw ArgumentError('consultation.id is required');
    }

    final now = DateTime.now();
    final batch = _db.batch();
    final consultationRef = _consultationRef(
      consultation.patientId,
      consultationId,
    );
    final clinicalFileIds = clinicalFiles.map((file) => file.id).toList();

    batch.set(consultationRef, {
      ...consultation.toJson(),
      'clinicalFileIds': clinicalFileIds,
    }, SetOptions(merge: true));

    for (final file in clinicalFiles) {
      final fileRef = _db
          .collection(FirestorePaths.patientClinicalFiles(file.patientId))
          .doc(file.id);
      batch.set(fileRef, file.toJson(), SetOptions(merge: true));
    }

    final cleanTreatmentId = treatmentId?.trim();
    final hasTreatment =
        cleanTreatmentId != null && cleanTreatmentId.isNotEmpty;
    final shouldMirrorToPatientHistory = !hasTreatment || treatmentIsPrimary;
    final shouldUpdateStageProjection =
        advancePhase && resultingStage != currentStage;

    final historyEntry = StageHistoryEntry(
      id: '',
      patientId: consultation.patientId,
      treatmentId: cleanTreatmentId ?? '',
      etapaAnterior: currentStage,
      etapaNueva: resultingStage,
      esRetroceso:
          TreatmentStage.values.indexOf(resultingStage) <
          TreatmentStage.values.indexOf(currentStage),
      notas: stageSummary,
      motivoCambio: stageReason,
      diagnosticoBreve: consultation.clinicalNotes,
      planSiguienteEtapa: nextStagePlan,
      adjuntosDescripcion: attachmentsSummary,
      consultationId: consultationId,
      signatureUrl: consultation.signatureUrl,
      fechaEfectiva: consultation.date,
      adminId: actorId,
      fechaCambio: now,
      status: 'completed',
      startedAt: consultation.date,
      completedAt: now,
    );

    if (hasTreatment) {
      final treatmentRef = _db.doc(
        FirestorePaths.patientTreatmentDoc(
          consultation.patientId,
          cleanTreatmentId,
        ),
      );
      if (shouldUpdateStageProjection) {
        batch.update(treatmentRef, {
          'etapaActual': resultingStage.name,
          'currentStageId': resultingStage.name,
          'currentStageName': stageNames[resultingStage] ?? resultingStage.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final treatmentHistoryRef = _db
          .collection(
            FirestorePaths.treatmentStageHistory(
              consultation.patientId,
              cleanTreatmentId,
            ),
          )
          .doc();
      batch.set(
        treatmentHistoryRef,
        historyEntry
            .copyWith(id: treatmentHistoryRef.id, treatmentId: cleanTreatmentId)
            .toJson(),
      );
    }

    if (shouldMirrorToPatientHistory) {
      final patientRef = _db
          .collection(FirestorePaths.patients)
          .doc(consultation.patientId);
      if (shouldUpdateStageProjection) {
        batch.update(patientRef, {
          'etapaActual': resultingStage.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final patientHistoryRef = _db
          .collection(FirestorePaths.stageHistory(consultation.patientId))
          .doc();
      batch.set(
        patientHistoryRef,
        historyEntry
            .copyWith(
              id: patientHistoryRef.id,
              treatmentId: cleanTreatmentId ?? '',
            )
            .toJson(),
      );
    }

    if (appointmentId.trim().isNotEmpty) {
      batch.update(
        _db.collection(FirestorePaths.appointments).doc(appointmentId),
        {
          'estado': AppointmentStatus.completada.name,
          'lastActionByRole': 'admin',
          'lastActionBy': actorId,
          'updatedByRole': 'admin',
          'updatedBy': actorId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  Future<void> updateConsultation(
    String patientId,
    String consultationId,
    Map<String, dynamic> data,
  ) async {
    await _consultationsRef(patientId).doc(consultationId).update(data);
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

    await _consultationsRef(patientId).doc(consultationId).update(updateData);
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
