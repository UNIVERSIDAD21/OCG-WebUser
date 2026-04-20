import 'package:firebase_storage/firebase_storage.dart';

import '../../../../shared/constants/storage_paths.dart';
import 'clinical_file_picker_service.dart';

class ClinicalFilesStorageService {
  ClinicalFilesStorageService(this._storage);

  final FirebaseStorage _storage;

  void _trace(String action, Map<String, Object?> details) {
    // ignore: avoid_print
    print('[ClinicalFilesStorageService][$action] $details');
  }

  Future<String> upload({
    required String patientId,
    String? treatmentId,
    required String fileId,
    required PickedClinicalFile file,
  }) async {
    final path = StoragePaths.patientClinicalFile(
      patientId,
      fileId,
      file.fileName,
      treatmentId: treatmentId,
    );
    _trace('upload.start', {
      'patientId': patientId,
      'treatmentId': treatmentId,
      'path': path,
      'fileName': file.fileName,
      'mimeType': file.mimeType,
      'sizeBytes': file.sizeBytes,
    });

    final ref = _storage.ref(path);
    try {
      await ref.putData(
        file.bytes,
        SettableMetadata(contentType: file.mimeType),
      );
      final url = await ref.getDownloadURL();
      _trace('upload.success', {
        'patientId': patientId,
        'treatmentId': treatmentId,
        'path': path,
      });
      return url;
    } catch (error) {
      _trace('upload.error', {
        'patientId': patientId,
        'treatmentId': treatmentId,
        'path': path,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<void> deleteByPath(String path) async {
    await _storage.ref(path).delete();
  }
}
