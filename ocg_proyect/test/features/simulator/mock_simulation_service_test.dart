import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ocg_proyect/services/simulator/mock_simulation_service.dart';

void main() {
  test('genera resultado mock válido sin cambiar dimensiones', () {
    final source = img.Image(width: 64, height: 48);
    img.fill(source, color: img.ColorRgb8(210, 200, 180));

    final originalBytes = Uint8List.fromList(img.encodeJpg(source, quality: 92));

    final service = MockSimulationService();
    final outBytes = service.generateMockResult(originalBytes);

    final decoded = img.decodeImage(outBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 64);
    expect(decoded.height, 48);
  });
}
