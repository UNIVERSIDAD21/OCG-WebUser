import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionResult {
  const FaceDetectionResult({
    required this.hasFace,
    required this.detectedRegion,
    required this.source,
  });

  final bool hasFace;
  final Map<String, dynamic>? detectedRegion;
  final String source;
}

class FaceDetectionService {
  Future<FaceDetectionResult> detectSmileRegion({required String imagePath}) async {
    if (kIsWeb) {
      return const FaceDetectionResult(
        hasFace: false,
        detectedRegion: null,
        source: 'mlkit_unavailable_web',
      );
    }

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
    );

    final detector = FaceDetector(options: options);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await detector.processImage(inputImage);
      if (faces.isEmpty) {
        return const FaceDetectionResult(hasFace: false, detectedRegion: null, source: 'no_face');
      }

      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;
      final box = face.boundingBox;

      // Región sugerida orientativa de sonrisa (tercio inferior del rostro + márgenes suaves)
      final suggested = {
        'x': box.left + (box.width * 0.16),
        'y': box.top + (box.height * 0.56),
        'w': box.width * 0.68,
        'h': box.height * 0.28,
        'unit': 'pixels',
        'kind': 'smile_region_suggestion',
      };

      return FaceDetectionResult(
        hasFace: true,
        detectedRegion: suggested,
        source: 'mlkit_face_detector',
      );
    } catch (_) {
      return const FaceDetectionResult(hasFace: false, detectedRegion: null, source: 'mlkit_error');
    } finally {
      await detector.close();
    }
  }
}
