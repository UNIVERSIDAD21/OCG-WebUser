import 'dart:typed_data';

import 'package:image/image.dart' as img;

class MockSimulationService {
  Uint8List generateMockResult(Uint8List originalBytes) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) return originalBytes;

    final out = img.Image.from(decoded);

    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);

        var r = p.r.toDouble();
        var g = p.g.toDouble();
        var b = p.b.toDouble();

        // Ajustes suaves (orientativos):
        // - brillo ligero
        // - contraste controlado
        // - reducción sutil de dominante amarilla
        r = ((r - 128.0) * 1.04) + 128.0 + 2.0;
        g = ((g - 128.0) * 1.03) + 128.0 + 2.0;
        b = ((b - 128.0) * 1.03) + 128.0 + 3.0;

        // Limitar para evitar aspecto artificial.
        r = r.clamp(0.0, 255.0);
        g = g.clamp(0.0, 255.0);
        b = b.clamp(0.0, 255.0);

        out.setPixelRgba(x, y, r.round(), g.round(), b.round(), p.a.round());
      }
    }

    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }
}
