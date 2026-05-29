import '../../features/simulator/domain/dental_treatment_profile.dart';
import '../firebase/face_detection_service.dart';

class PhotoQualityResult {
  const PhotoQualityResult({
    required this.status,
    required this.score,
    required this.warnings,
    required this.blockingReasons,
    required this.metadata,
  });

  final String status; // valid | usable_with_warning | rejected
  final double score;
  final List<String> warnings;
  final List<String> blockingReasons;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'status': status,
    'score': score,
    'warnings': warnings,
    'blockingReasons': blockingReasons,
    'metadata': metadata,
  };

  factory PhotoQualityResult.fromJson(Map<String, dynamic> json) {
    return PhotoQualityResult(
      status: (json['status'] ?? 'valid').toString(),
      score: (json['score'] ?? 0.5) is int
          ? (json['score'] as int).toDouble()
          : (json['score'] ?? 0.5) as double,
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      blockingReasons:
          (json['blockingReasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  static const valid = PhotoQualityResult(
    status: 'valid',
    score: 1.0,
    warnings: [],
    blockingReasons: [],
    metadata: {},
  );

  static const rejectedNoFace = PhotoQualityResult(
    status: 'rejected',
    score: 0.0,
    warnings: [],
    blockingReasons: ['No se detectó un rostro en la foto.'],
    metadata: {'hasFace': false},
  );

  static const rejectedNoTeeth = PhotoQualityResult(
    status: 'rejected',
    score: 0.0,
    warnings: [],
    blockingReasons: ['No se detectaron dientes visibles en la foto.'],
    metadata: {'hasFace': false},
  );
}

class PhotoQualityService {
  /// Evaluates photo quality and compatibility with the chosen treatment profile.
  PhotoQualityResult evaluate({
    required int bytesLength,
    required FaceDetectionResult detection,
    required String? treatmentProfileId,
    required Map<String, dynamic>? doctorConfig,
  }) {
    final warnings = <String>[];
    final blockingReasons = <String>[];
    double score = 1.0;
    final metadata = <String, dynamic>{
      'hasFace': detection.hasFace,
      'faceDetectionSource': detection.source,
    };

    final profile = treatmentProfileId != null
        ? lookupProfile(treatmentProfileId)
        : null;

    // ── 1. File size ──────────────────────────────────────
    if (bytesLength < 1024) {
      blockingReasons.add('La imagen es demasiado pequeña o está vacía.');
    } else if (bytesLength < 20 * 1024 && bytesLength >= 1024) {
      warnings.add('La imagen tiene baja resolución.');
      score -= 0.1;
    }

    // ── 2. Face detection ─────────────────────────────────
    final mlKitAvailable =
        detection.source != 'mlkit_unavailable_web' &&
        detection.source != 'mlkit_error';

    if (mlKitAvailable && !detection.hasFace) {
      blockingReasons.add(
        'No se detectó un rostro en la foto. Toma una foto frontal clara.',
      );
      score = 0.0;
    }

    if (!mlKitAvailable) {
      metadata['photoType'] = 'unverified';
      if (!detection.hasFace) {
        warnings.add(
          'No se pudo verificar automáticamente la foto.'
          ' Asegúrate manualmente de que los dientes sean visibles.',
        );
        score -= 0.15;
      }
    }

    // ── 3. Smile region ───────────────────────────────────
    if (detection.hasFace && detection.detectedRegion != null) {
      final region = detection.detectedRegion!;
      final w = (region['w'] as num?)?.toDouble() ?? 0;
      final h = (region['h'] as num?)?.toDouble() ?? 0;
      final area = w * h;

      if (area < 1000) {
        warnings.add(
          'La región dental detectada es muy pequeña.'
          ' Acerca la cámara a la sonrisa del paciente.',
        );
        score -= 0.1;
      }
      if (w > 0 && h > 0 && (w / h < 0.5 || w / h > 8)) {
        warnings.add(
          'La proporción de la región dental parece atípica.'
          ' Verifica el encuadre.',
        );
        score -= 0.05;
      }
    }

    // ── 4. Treatment-specific rules ───────────────────────
    if (profile != null) {
      metadata['treatmentProfileId'] = profile.id;

      switch (profile.id) {
        case 'metal_braces':
        case 'esthetic_braces':
          _assessSmileVisible(warnings, blockingReasons, detection, score);
          break;

        case 'clear_aligners':
          _assessSmileVisible(warnings, blockingReasons, detection, score);
          if (!detection.hasFace && !mlKitAvailable) {
            warnings.add(
              'Para alineadores, una foto frontal clara de la sonrisa'
              ' da mejores resultados.',
            );
          }
          break;

        case 'blanqueamiento':
          _assessSmileVisible(warnings, blockingReasons, detection, score);
          break;

        case 'carillas':
        case 'reconstruccion':
        case 'limpieza_oral':
        case 'reemplazo_dental':
        case 'implantes_dentales':
        case 'bordes_incisales':
        case 'gingivectomia':
        case 'gingivoplastia':
        case 'alineacion_margenes':
          _assessSmileVisible(warnings, blockingReasons, detection, score);
          if (detection.detectedRegion == null && !detection.hasFace) {
            warnings.add(
              'Para este tratamiento se recomienda una foto frontal'
              ' con sonrisa amplia y dientes bien visibles.',
            );
          }
          break;

        case 'palatal_expander':
          // Expander requires intraoral upper photo
          final configType = doctorConfig?['tipoVisual']?.toString() ?? 'Hyrax';
          if (configType == 'removible') {
            warnings.add(
              'El expansor removible puede no ser visible en una'
              ' sonrisa frontal. Considera usar una foto intraoral.',
            );
          } else {
            blockingReasons.add(
              'Para simular un expansor de paladar (${profile.label}),'
              ' necesitas una foto intraoral superior donde se vea el'
              ' paladar. Una sonrisa frontal no muestra el expansor.',
            );
          }
          metadata['photoType'] = 'frontal_smile';
          score = 0.0;
          break;

        case 'retainer':
          final tipo = doctorConfig?['tipo']?.toString() ?? 'Essix';
          if (tipo == 'fijo lingual') {
            warnings.add(
              'El retenedor fijo lingual va detrás de los dientes'
              ' y no será visible en una foto frontal.'
              ' La simulación puede no mostrar diferencia.',
            );
            metadata['photoType'] = 'frontal_smile_limited';
          }
          _assessSmileVisible(warnings, blockingReasons, detection, score);
          break;
      }
    }

    // Clamp score
    score = score.clamp(0.0, 1.0);

    // Determine final status
    final String status;
    if (blockingReasons.isNotEmpty) {
      status = 'rejected';
    } else if (warnings.isNotEmpty) {
      status = 'usable_with_warning';
    } else {
      status = 'valid';
    }

    return PhotoQualityResult(
      status: status,
      score: score,
      warnings: warnings,
      blockingReasons: blockingReasons,
      metadata: metadata,
    );
  }

  void _assessSmileVisible(
    List<String> warnings,
    List<String> blockingReasons,
    FaceDetectionResult detection,
    double score,
  ) {
    if (detection.source == 'no_face') {
      blockingReasons.add(
        'No se detectaron dientes visibles.'
        ' Toma una foto frontal con la boca del paciente sonriendo.',
      );
    }
  }
}
