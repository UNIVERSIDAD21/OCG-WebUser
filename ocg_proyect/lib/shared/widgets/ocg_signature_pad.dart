import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../shared/theme/ocg_colors.dart';

/// Widget profesional de firma con CustomPainter.
///
/// Soporta múltiples trazos (levantar el dedo y seguir firmando).
/// Diseño premium alineado con la estética OCG (espresso/bronze/ivory).
class OcgSignaturePad extends StatefulWidget {
  const OcgSignaturePad({
    super.key,
    this.height = 200,
    this.penColor = const Color(0xFF3D2B1F),
    this.penWidth = 2.5,
    this.onSignatureReady,
    this.onSignatureCleared,
    this.backgroundDecoration,
  });

  final double height;
  final Color penColor;
  final double penWidth;

  /// Callback con los bytes PNG cuando el usuario confirma la firma.
  final ValueChanged<Uint8List>? onSignatureReady;

  /// Callback cuando se limpia la firma.
  final VoidCallback? onSignatureCleared;

  final BoxDecoration? backgroundDecoration;

  @override
  OcgSignaturePadState createState() => OcgSignaturePadState();
}

class OcgSignaturePadState extends State<OcgSignaturePad>
    with TickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final GlobalKey _painterKey = GlobalKey();
  late AnimationController _confirmController;
  late Animation<double> _confirmAnim;

  bool _isDrawing = false;

  bool get _isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;

  @override
  void initState() {
    super.initState();
    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _confirmAnim = CurvedAnimation(
      parent: _confirmController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
      _isDrawing = false;
    });
    if (_confirmController.isCompleted) {
      _confirmController.reset();
    }
    widget.onSignatureCleared?.call();
  }

  /// Exporta la firma como PNG y dispara el callback.
  Future<void> confirmSignature() async {
    if (_isEmpty) return;
    final bytes = await _toPngInternal();
    if (bytes != null) {
      widget.onSignatureReady?.call(bytes);
      _confirmController.forward();
    }
  }

  Future<Uint8List?> _toPngInternal() async {
    final boundary = _painterKey.currentContext?.findRenderObject();
    if (boundary == null || boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final bgDecoration =
        widget.backgroundDecoration ??
        BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: OcgColors.bronze.withOpacity(0.2),
            width: 1,
          ),
        );

    return Container(
      height: widget.height,
      decoration: bgDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Patrón de fondo sutil (líneas de documento)
            Positioned.fill(
              child: CustomPaint(painter: _DocumentPatternPainter()),
            ),
            // Área de firma
            Positioned.fill(
              // Usamos GestureDetector (no Listener) para ganar el gesture arena
              // de Flutter y evitar que el Scrollable padre capture los drags.
              // onPanDown con return true consume el touch inmediatamente.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanDown: (details) {
                  final box = _painterKey.currentContext?.findRenderObject();
                  if (box == null || box is! RenderBox) return;
                  final local = box.globalToLocal(details.globalPosition);
                  setState(() {
                    _currentStroke = [local];
                    _isDrawing = true;
                  });
                },
                onPanUpdate: (details) {
                  if (!_isDrawing) return;
                  final box = _painterKey.currentContext?.findRenderObject();
                  if (box == null || box is! RenderBox) return;
                  final local = box.globalToLocal(details.globalPosition);
                  setState(() {
                    _currentStroke = [..._currentStroke, local];
                  });
                },
                onPanEnd: (_) {
                  if (_currentStroke.length > 1) {
                    setState(() {
                      _strokes.add(List.from(_currentStroke));
                      _currentStroke = [];
                      _isDrawing = false;
                    });
                  } else {
                    setState(() {
                      _currentStroke = [];
                      _isDrawing = false;
                    });
                  }
                },
                onPanCancel: () {
                  setState(() {
                    _currentStroke = [];
                    _isDrawing = false;
                  });
                },
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
                                  Icons.draw_outlined,
                                  size: 36,
                                  color: OcgColors.bronze.withOpacity(0.35),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Firme aquí',
                                  style: TextStyle(
                                    color: OcgColors.bronze.withOpacity(0.5),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Cormorant Garamond',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Use el dedo o un stylus',
                                  style: TextStyle(
                                    color: OcgColors.bronze.withOpacity(0.3),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            // Línea de firma profesional
            if (_isEmpty)
              Positioned(
                left: 32,
                right: 32,
                bottom: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              OcgColors.bronze.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '✕',
                        style: TextStyle(
                          color: OcgColors.bronze.withOpacity(0.25),
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              OcgColors.bronze.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Marca de agua inferior
            if (_isEmpty)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'FIRMA DEL PACIENTE',
                    style: TextStyle(
                      color: OcgColors.bronze.withOpacity(0.12),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            // Animación de confirmación
            if (!_isEmpty && _confirmController.isCompleted)
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF166534).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF166534),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Patrón sutil de líneas de documento.
class _DocumentPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8DDD0).withOpacity(0.3)
      ..strokeWidth = 0.5;

    for (double y = 20; y < size.height - 50; y += 24) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentPatternPainter oldDelegate) => false;
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
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
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
