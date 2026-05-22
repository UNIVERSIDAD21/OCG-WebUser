import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/shared/widgets/ocg_signature_pad.dart';

void main() {
  testWidgets('captura trazos dentro de un scroll sin romper gestos', (
    tester,
  ) async {
    var hasInk = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 500),
                OcgSignaturePad(
                  height: 220,
                  onInkChanged: (value) => hasInk = value,
                ),
                const SizedBox(height: 500),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(OcgSignaturePad));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(OcgSignaturePad));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(80, 18));
    await gesture.moveBy(const Offset(40, -12));
    await gesture.up();
    await tester.pump();

    expect(hasInk, isTrue);
    expect(tester.takeException(), isNull);
  });
}
