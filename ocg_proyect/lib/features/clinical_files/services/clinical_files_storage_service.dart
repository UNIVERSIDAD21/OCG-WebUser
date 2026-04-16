import 'package:firebase_storage/firebase_storage.dart';

import '../../../../shared/constants/storage_paths.dart';
import 'clinical_file_picker_service.dart';

class ClinicalFilesStorageService {
  ClinicalFilesStorageService(this._storage);

  final FirebaseStorage _storage;

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
    final ref = _storage.ref(path);
    await ref.putData(file.bytes, SettableMetadata(contentType: file.mimeType));
    return ref.getDownloadURL();
  }
}
