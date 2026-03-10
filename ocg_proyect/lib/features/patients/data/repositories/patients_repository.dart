import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/patient_model.dart';

class PatientsRepository {
  PatientsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _patientsRef =>
      _db.collection(FirestorePaths.patients);

  Stream<List<PatientModel>> watchAllPatients() {
    return _patientsRef
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PatientModel.fromJson(doc.data())).toList());
  }

  Stream<PatientModel?> watchPatient(String patientId) {
    return _patientsRef.doc(patientId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return PatientModel.fromJson(data);
    });
  }

  Future<void> createPatient(PatientModel patient) async {
    await _patientsRef.doc(patient.id).set(patient.toJson(), SetOptions(merge: true));
  }

  Future<void> updatePatientClinicalData(String patientId, Map<String, dynamic> data) async {
    await _patientsRef.doc(patientId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePatientBasicData(String patientId, Map<String, dynamic> data) async {
    await _patientsRef.doc(patientId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePatientContactData(
    String patientId, {
    String? telefono,
    String? fotoUrl,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (telefono != null) data['telefono'] = telefono;
    if (fotoUrl != null) data['fotoUrl'] = fotoUrl;

    await _patientsRef.doc(patientId).update(data);
  }


  Future<void> deletePatient(String patientId) async {
    await _db.collection(FirestorePaths.patients).doc(patientId).delete();
  }

  Future<void> updateTreatmentStage({
    required String patientId,
    required TreatmentStage newStage,
    required String notas,
    required String adminId,
  }) async {
    final batch = _db.batch();

    batch.update(_patientsRef.doc(patientId), {
      'etapaActual': newStage.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final historyRef = _db.collection(FirestorePaths.stageHistory(patientId)).doc();
    batch.set(historyRef, {
      'id': historyRef.id,
      'etapa': newStage.name,
      'fecha': FieldValue.serverTimestamp(),
      'notas': notas,
      'cambiadoPor': adminId,
      'fotosIds': <String>[],
    });

    await batch.commit();
  }
}
