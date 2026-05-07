import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/clinical_file_model.dart';

class ClinicalFilesRepository {
  ClinicalFilesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _filesRef(String patientId) =>
      _db.collection(FirestorePaths.patientClinicalFiles(patientId));

  void _trace(String action, Map<String, Object?> details) {
    // ignore: avoid_print
    print('[ClinicalFilesRepository][$action] $details');
  }

  Stream<List<ClinicalFileModel>> watchFiles(
    String patientId, {
    String? treatmentId,
    bool includeInactive = false,
    bool onlyVisibleToPatient = false,
  }) {
    _trace('watchFiles', {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'path': FirestorePaths.patientClinicalFiles(patientId),
      'onlyVisibleToPatient': onlyVisibleToPatient,
      'includeInactive': includeInactive,
    });

    Query<Map<String, dynamic>> query = _filesRef(patientId);

    if (onlyVisibleToPatient) {
      query = query
          .where('visibleToPatient', isEqualTo: true)
          .where('active', isEqualTo: true);
    } else {
      query = query.orderBy('uploadedAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      final files = snapshot.docs
          .map((doc) => ClinicalFileModel.fromJson(doc.data(), id: doc.id))
          .where((item) {
            if (!onlyVisibleToPatient && !includeInactive && !item.active) {
              return false;
            }
            if (treatmentId != null &&
                treatmentId.isNotEmpty &&
                item.treatmentId != treatmentId) {
              return false;
            }
            return true;
          })
          .toList();

      files.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return files;
    });
  }

  Future<void> saveMetadata(ClinicalFileModel file) async {
    _trace('saveMetadata.start', {
      'patientId': file.patientId,
      'fileId': file.id,
      'treatmentId': file.treatmentId,
      'path':
          '${FirestorePaths.patientClinicalFiles(file.patientId)}/${file.id}',
      'storagePath': file.storagePath,
    });
    try {
      await _filesRef(
        file.patientId,
      ).doc(file.id).set(file.toJson(), SetOptions(merge: true));
      _trace('saveMetadata.success', {
        'patientId': file.patientId,
        'fileId': file.id,
        'path':
            '${FirestorePaths.patientClinicalFiles(file.patientId)}/${file.id}',
      });
    } catch (error) {
      _trace('saveMetadata.error', {
        'patientId': file.patientId,
        'fileId': file.id,
        'path':
            '${FirestorePaths.patientClinicalFiles(file.patientId)}/${file.id}',
        'error': error.toString(),
      });
      rethrow;
    }
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
