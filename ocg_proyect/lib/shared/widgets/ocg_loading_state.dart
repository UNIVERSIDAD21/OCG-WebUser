import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

enum OcgLoadingVariant { inline, fullPage }

class OcgLoadingState extends StatefulWidget {
  const OcgLoadingState({
    super.key,
    this.label,
    this.variant = OcgLoadingVariant.inline,
  });

  final String? label;
  final OcgLoadingVariant variant;

  @override
  State<OcgLoadingState> createState() => _OcgLoadingStateState();
}

class _OcgLoadingStateState extends State<OcgLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFullPage = widget.variant == OcgLoadingVariant.fullPage;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spinner with subtle pulse
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            final scale = 1.0 + 0.04 * (1 - t);
            final opacity = 0.18 + 0.12 * t;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: isFullPage ? 56 : 40,
                    height: isFullPage ? 56 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC8AF8C).withOpacity(opacity),
                        width: isFullPage ? 2 : 1.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: isFullPage ? 28 : 22,
                  height: isFullPage ? 28 : 22,
                  child: CircularProgressIndicator(
                    strokeWidth: isFullPage ? 2.5 : 2,
                    color: const Color(0xFF6E5442),
                  ),
                ),
              ],
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OcgColors.ink.withOpacity(0.55),
              fontSize: isFullPage ? 14 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (isFullPage) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDE8DC), Color(0xFFF5F0E6)],
          ),
        ),
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}
