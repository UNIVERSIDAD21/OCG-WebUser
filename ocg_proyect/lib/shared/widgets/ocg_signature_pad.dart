import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/theme/ocg_colors.dart';

/// Canvas de firma para dictamen clinico.
///
/// Usa EagerGestureRecognizer para ganar la competencia contra el scroll padre,
/// y Listener para dibujar con eventos Pointer directos. Esto evita el crash de
/// PanGestureRecognizer custom en movil y web.
class OcgSignaturePad extends StatefulWidget {
  const OcgSignaturePad({
    super.key,
    this.height = 200,
    this.penColor = const Color(0xFF3D2B1F),
    this.penWidth = 2.5,
    this.onSignatureReady,
    this.onSignatureCleared,
    this.onInkChanged,
    this.backgroundDecoration,
  });

  final double height;
  final Color penColor;
  final double penWidth;
  final ValueChanged<Uint8List>? onSignatureReady;
  final VoidCallback? onSignatureCleared;
  final ValueChanged<bool>? onInkChanged;
  final BoxDecoration? backgroundDecoration;

  @override
  OcgSignaturePadState createState() => OcgSignaturePadState();
}

class OcgSignaturePadState extends State<OcgSignaturePad>
    with TickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final GlobalKey _painterKey = GlobalKey();
  late final AnimationController _confirmController;

  bool _isDrawing = false;
  bool _lastReportedHasInk = false;
  int? _activePointer;

  bool get _isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;
  bool get _hasDrawableInk =>
      _strokes.any((stroke) => stroke.length > 1) || _currentStroke.length > 1;

  bool get hasInk => _hasDrawableInk;

  @override
  void initState() {
    super.initState();
    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
      _activePointer = null;
    });
    if (_confirmController.isCompleted) {
      _confirmController.reset();
    }
    _notifyInkChanged();
    widget.onSignatureCleared?.call();
  }

  Future<void> confirmSignature() async {
    if (!_hasDrawableInk) return;
    final bytes = await _toPngInternal();
    if (bytes != null) {
      if (mounted) {
        _confirmController.forward(from: 0);
      }
      widget.onSignatureReady?.call(bytes);
    }
  }

  Future<Uint8List?> _toPngInternal() async {
    final boundary = _painterKey.currentContext?.findRenderObject();
    if (boundary == null || boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _notifyInkChanged() {
    final hasInkNow = _hasDrawableInk;
    if (hasInkNow == _lastReportedHasInk) return;
    _lastReportedHasInk = hasInkNow;
    widget.onInkChanged?.call(hasInkNow);
  }

  Offset? _localPositionFor(PointerEvent event) {
    final renderObject = _painterKey.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return null;

    final local = renderObject.globalToLocal(event.position);
    final size = renderObject.size;
    return Offset(
      local.dx.clamp(0.0, size.width).toDouble(),
      local.dy.clamp(0.0, size.height).toDouble(),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    final local = _localPositionFor(event);
    if (local == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    if (_confirmController.isCompleted) {
      _confirmController.reset();
    }

    setState(() {
      _activePointer = event.pointer;
      _currentStroke = [local];
      _isDrawing = true;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDrawing || event.pointer != _activePointer) return;
    final local = _localPositionFor(event);
    if (local == null) return;
    if (_currentStroke.isNotEmpty &&
        (_currentStroke.last - local).distance < 0.5) {
      return;
    }

    setState(() {
      _currentStroke = [..._currentStroke, local];
    });
    _notifyInkChanged();
  }

  void _finishStroke(int pointer) {
    if (pointer != _activePointer) return;

    setState(() {
      if (_currentStroke.length > 1) {
        _strokes.add(List<Offset>.from(_currentStroke));
      }
      _currentStroke = [];
      _isDrawing = false;
      _activePointer = null;
    });
    _notifyInkChanged();
  }

  void _cancelStroke(int pointer) {
    if (pointer != _activePointer) return;

    setState(() {
      _currentStroke = [];
      _isDrawing = false;
      _activePointer = null;
    });
    _notifyInkChanged();
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
            Positioned.fill(
              child: CustomPaint(painter: _DocumentPatternPainter()),
            ),
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(() => EagerGestureRecognizer(), (_) {}),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: (event) => _finishStroke(event.pointer),
                  onPointerCancel: (event) => _cancelStroke(event.pointer),
                  child: RepaintBoundary(
                    key: _painterKey,
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        penColor: widget.penColor,
                        penWidth: widget.penWidth,
                      ),
                      child: _isEmpty ? const _SignaturePlaceholder() : null,
                    ),
                  ),
                ),
              ),
            ),
            if (_isEmpty) const _SignatureBaseline(),
            if (!_isEmpty && _confirmController.isCompleted)
              const _SignatureConfirmedMark(),
          ],
        ),
      ),
    );
  }
}

class _SignaturePlaceholder extends StatelessWidget {
  const _SignaturePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
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
            'Firme aqui',
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
    );
  }
}

class _SignatureBaseline extends StatelessWidget {
  const _SignatureBaseline();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
                  'x',
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
      ],
    );
  }
}

class _SignatureConfirmedMark extends StatelessWidget {
  const _SignatureConfirmedMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF166534).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF166534), width: 2),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 40,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

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

    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }

    final last = points[points.length - 1];
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
