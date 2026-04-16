import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedClinicalFile {
  const PickedClinicalFile({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
  });

  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
}

class ClinicalFilePickerService {
  Future<PickedClinicalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    final extension = (file.extension ?? '').toLowerCase();
    return PickedClinicalFile(
      bytes: bytes,
      fileName: file.name,
      extension: extension,
      mimeType: _mimeFromExtension(extension),
      sizeBytes: file.size,
    );
  }

  String _mimeFromExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
