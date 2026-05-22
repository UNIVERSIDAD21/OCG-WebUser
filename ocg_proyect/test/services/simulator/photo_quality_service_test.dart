import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/services/firebase/face_detection_service.dart';
import 'package:ocg_proyect/services/simulator/photo_quality_service.dart';

void main() {
  final service = PhotoQualityService();

  group('PhotoQualityService', () {
    test('ML Kit detecta rostro => status valid', () {
      final result = service.evaluate(
        bytesLength: 500 * 1024,
        detection: const FaceDetectionResult(
          hasFace: true,
          detectedRegion: {
            'x': 100,
            'y': 200,
            'w': 300,
            'h': 100,
            'unit': 'pixels',
          },
          source: 'mlkit_face_detector',
        ),
        treatmentProfileId: 'metal_braces',
        doctorConfig: null,
      );

      expect(result.status, 'valid');
      expect(result.score, greaterThan(0.9));
      expect(result.blockingReasons, isEmpty);
    });

    test('ML Kit no detecta rostro => status rejected', () {
      final result = service.evaluate(
        bytesLength: 500 * 1024,
        detection: const FaceDetectionResult(
          hasFace: false,
          detectedRegion: null,
          source: 'no_face',
        ),
        treatmentProfileId: 'whitening',
        doctorConfig: null,
      );

      expect(result.status, 'rejected');
      expect(result.blockingReasons, isNotEmpty);
      expect(
        result.blockingReasons
            .any((r) => r.contains('dientes visibles')),
        isTrue,
      );
    });

    test('expansor de paladar => siempre rejected en foto frontal', () {
      final result = service.evaluate(
        bytesLength: 500 * 1024,
        detection: const FaceDetectionResult(
          hasFace: true,
          detectedRegion: {
            'x': 100,
            'y': 200,
            'w': 300,
            'h': 100,
          },
          source: 'mlkit_face_detector',
        ),
        treatmentProfileId: 'palatal_expander',
        doctorConfig: {'tipoVisual': 'Hyrax'},
      );

      expect(result.status, 'rejected');
      expect(
        result.blockingReasons
            .any((r) => r.contains('intraoral')),
        isTrue,
      );
    });

    test('retenedor fijo lingual => warning, no bloqueo', () {
      final result = service.evaluate(
        bytesLength: 500 * 1024,
        detection: const FaceDetectionResult(
          hasFace: true,
          detectedRegion: {
            'x': 100,
            'y': 200,
            'w': 300,
            'h': 100,
          },
          source: 'mlkit_face_detector',
        ),
        treatmentProfileId: 'retainer',
        doctorConfig: {'tipo': 'fijo lingual'},
      );

      expect(result.status, 'usable_with_warning');
      expect(result.blockingReasons, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('web sin ML Kit => warning pero no bloquea', () {
      final result = service.evaluate(
        bytesLength: 500 * 1024,
        detection: const FaceDetectionResult(
          hasFace: false,
          detectedRegion: null,
          source: 'mlkit_unavailable_web',
        ),
        treatmentProfileId: 'smile_design',
        doctorConfig: null,
      );

      expect(result.status, 'usable_with_warning');
      expect(result.blockingReasons, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('imagen muy pequeña => rejected', () {
      final result = service.evaluate(
        bytesLength: 500,
        detection: const FaceDetectionResult(
          hasFace: false,
          detectedRegion: null,
          source: 'mlkit_error',
        ),
        treatmentProfileId: 'metal_braces',
        doctorConfig: null,
      );

      expect(result.status, 'rejected');
      expect(result.blockingReasons, isNotEmpty);
    });

    test('PhotoQualityResult.fromJson restaura desde mapa', () {
      final json = {
        'status': 'usable_with_warning',
        'score': 0.72,
        'warnings': ['Poca luz'],
        'blockingReasons': [],
        'metadata': {'hasFace': true},
      };

      final result = PhotoQualityResult.fromJson(json);
      expect(result.status, 'usable_with_warning');
      expect(result.score, 0.72);
      expect(result.warnings, ['Poca luz']);
      expect(result.blockingReasons, isEmpty);
      expect(result.metadata['hasFace'], true);
    });
  });
}
