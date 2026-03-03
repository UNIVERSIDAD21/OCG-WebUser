import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({super.key, required this.before, required this.after, this.height = 220});

  final ImageProvider before;
  final ImageProvider after;
  final double height;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final split = width * _position;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _position = (_position + details.delta.dx / width).clamp(0.0, 1.0);
            });
          },
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                Positioned.fill(child: Image(image: widget.before, fit: BoxFit.cover)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: split,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _position,
                      child: Image(image: widget.after, fit: BoxFit.cover, width: width),
                    ),
                  ),
                ),
                Positioned(
                  left: split - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
                Positioned(
                  left: split - 14,
                  top: (widget.height / 2) - 14,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: const Icon(Icons.drag_indicator, size: 16),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
