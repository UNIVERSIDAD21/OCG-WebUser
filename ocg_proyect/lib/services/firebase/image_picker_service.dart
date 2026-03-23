import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedImageData {
  const PickedImageData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedImageData?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<PickedImageData?> pickFromCamera() => _pick(ImageSource.camera);

  Future<PickedImageData?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final path = file.path.toLowerCase();
    final mime = path.endsWith('.png') ? 'image/png' : 'image/jpeg';

    return PickedImageData(
      bytes: bytes,
      fileName: file.name,
      mimeType: mime,
    );
  }
}
