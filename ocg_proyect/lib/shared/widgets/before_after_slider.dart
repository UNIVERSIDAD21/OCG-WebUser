import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget before;
  final Widget after;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;

  void _setFromDx(double localDx, double width) {
    if (width <= 0) return;
    final p = (localDx / width).clamp(0.0, 1.0);
    setState(() => _position = p);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerLeft = width * _position;

        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => _setFromDx(details.localPosition.dx, width),
            onTapDown: (details) => _setFromDx(details.localPosition.dx, width),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(child: widget.before),
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _LeftClipper(_position),
                      child: widget.after,
                    ),
                  ),
                  Positioned(
                    left: dividerLeft - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white.withOpacity(0.95)),
                  ),
                  Positioned(
                    left: dividerLeft - 18,
                    top: (widget.height / 2) - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF6F5A48), width: 2),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.compare_arrows, size: 18, color: Color(0xFF6F5A48)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeftClipper extends CustomClipper<Path> {
  _LeftClipper(this.factor);

  final double factor;

  @override
  Path getClip(Size size) {
    final w = size.width * factor;
    return Path()..addRect(Rect.fromLTWH(0, 0, w, size.height));
  }

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.factor != factor;
}
