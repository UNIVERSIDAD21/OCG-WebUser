import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../shared/theme/ocg_colors.dart';

/// Widget profesional de firma con CustomPainter.
///
/// Captura trazos del dedo/stylus y exporta como PNG.
/// Diseño alineado con la estética OCG (espresso/bronze/ivory).
class OcgSignaturePad extends StatefulWidget {
  const OcgSignaturePad({
    super.key,
    this.height = 180,
    this.penColor = OcgColors.espresso,
    this.penWidth = 2.0,
    this.onSignatureChanged,
    this.onSignatureCleared,
    this.backgroundDecoration,
  });

  final double height;
  final Color penColor;
  final double penWidth;

  /// Callback que recibe los bytes PNG cuando la firma cambia.
  final ValueChanged<Uint8List>? onSignatureChanged;

  /// Callback cuando se limpia la firma.
  final VoidCallback? onSignatureCleared;

  final BoxDecoration? backgroundDecoration;

  @override
  OcgSignaturePadState createState() => OcgSignaturePadState();
}

class OcgSignaturePadState extends State<OcgSignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final GlobalKey _painterKey = GlobalKey();

  bool get _isEmpty => _strokes.isEmpty;

  void _onPanStart(DragStartDetails details) {
    final box = _painterKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke = [local];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _painterKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke = [..._currentStroke, local];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke.length > 1) {
      setState(() {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      });
      _exportPng();
    } else {
      setState(() {
        _currentStroke = [];
      });
    }
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
    widget.onSignatureCleared?.call();
  }

  Future<void> _exportPng() async {
    if (_isEmpty) return;
    final bytes = await _toPngInternal();
    if (bytes != null) {
      widget.onSignatureChanged?.call(bytes);
    }
  }

  Future<Uint8List?> _toPngInternal() async {
    final boundary =
        _painterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Método público para obtener los bytes PNG de la firma actual.
  Future<Uint8List?> toPng() async {
    if (_isEmpty) return null;
    return _toPngInternal();
  }

  @override
  Widget build(BuildContext context) {
    final bgDecoration = widget.backgroundDecoration ??
        BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: OcgColors.bronze.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        );

    return Container(
      height: widget.height,
      decoration: bgDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Área de firma
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: RepaintBoundary(
                key: _painterKey,
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    penColor: widget.penColor,
                    penWidth: widget.penWidth,
                  ),
                  child: _isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 32,
                                color: OcgColors.bronze.withOpacity(0.35),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Firme aquí con el dedo',
                                style: TextStyle(
                                  color: OcgColors.bronze.withOpacity(0.45),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
            ),
            // Línea guía
            if (_isEmpty)
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        OcgColors.bronze.withOpacity(0),
                        OcgColors.bronze.withOpacity(0.25),
                        OcgColors.bronze.withOpacity(0.25),
                        OcgColors.bronze.withOpacity(0),
                      ],
                      stops: const [0, 0.15, 0.85, 1],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penWidth,
  });

  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = penWidth;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        mid.dx,
        mid.dy,
      );
    }

    if (points.length >= 2) {
      final last = points[points.length - 1];
      path.lineTo(last.dx, last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
