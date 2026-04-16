import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/clinical_file_model.dart';

class ClinicalFilesRepository {
  ClinicalFilesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _filesRef(String patientId) =>
      _db.collection(FirestorePaths.patientClinicalFiles(patientId));

  Stream<List<ClinicalFileModel>> watchFiles(
    String patientId, {
    String? treatmentId,
    bool includeInactive = false,
    bool onlyVisibleToPatient = false,
  }) {
    return _filesRef(patientId).orderBy('uploadedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ClinicalFileModel.fromJson(doc.data(), id: doc.id))
          .where((item) {
            if (!includeInactive && !item.active) return false;
            if (onlyVisibleToPatient && !item.visibleToPatient) return false;
            if (treatmentId != null && treatmentId.isNotEmpty && item.treatmentId != treatmentId) return false;
            return true;
          })
          .toList();
    });
  }

  Future<void> saveMetadata(ClinicalFileModel file) async {
    await _filesRef(file.patientId).doc(file.id).set(file.toJson(), SetOptions(merge: true));
  }

  Future<void> softDelete({
    required String patientId,
    required String fileId,
    required String deletedBy,
  }) async {
    await _filesRef(patientId).doc(fileId).update({
      'active': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': deletedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
