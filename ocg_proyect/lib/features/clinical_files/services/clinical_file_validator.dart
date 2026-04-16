import 'clinical_file_picker_service.dart';

class ClinicalFileValidator {
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxPdfBytes = 20 * 1024 * 1024;
  static const Set<String> allowedExtensions = <String>{'pdf', 'jpg', 'jpeg', 'png', 'webp'};

  void validate(PickedClinicalFile file) {
    final extension = file.extension.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw Exception('CLINICAL_FILE_EXTENSION_NOT_ALLOWED');
    }

    if (file.fileName.trim().isEmpty) {
      throw Exception('CLINICAL_FILE_NAME_REQUIRED');
    }

    final maxBytes = extension == 'pdf' ? maxPdfBytes : maxImageBytes;
    if (file.sizeBytes > maxBytes) {
      throw Exception('CLINICAL_FILE_TOO_LARGE');
    }
  }
}
