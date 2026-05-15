import 'package:flutter/material.dart';

class OcgSkeletonList extends StatelessWidget {
  const OcgSkeletonList({
    super.key,
    this.items = 3,
    this.cardHeight = 126,
    this.padding = const EdgeInsets.all(16),
    this.itemSpacing = 12,
    this.showAvatar = true,
    this.showAccent = true,
  });

  final int items;
  final double cardHeight;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final bool showAvatar;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    return _OcgShimmer(
      child: ListView.separated(
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items,
        separatorBuilder: (_, __) => SizedBox(height: itemSpacing),
        itemBuilder: (_, index) => OcgSkeletonCard(
          height: cardHeight,
          showAvatar: showAvatar,
          showAccent: showAccent,
          compact: index.isOdd,
        ),
      ),
    );
  }
}

class OcgSkeletonCard extends StatelessWidget {
  const OcgSkeletonCard({
    super.key,
    this.height = 126,
    this.showAvatar = true,
    this.showAccent = true,
    this.compact = false,
  });

  final double height;
  final bool showAvatar;
  final bool showAccent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFCF8F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DED2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2C2016),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAccent) Container(width: 5, color: const Color(0xFFD7C0A8)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    if (showAvatar) ...[
                      const _SkeletonBlock(width: 54, height: 54, radius: 16),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBlock(
                            width: compact ? 140 : 190,
                            height: 16,
                            radius: 8,
                          ),
                          const SizedBox(height: 10),
                          const _SkeletonBlock(
                            width: double.infinity,
                            height: 11,
                            radius: 7,
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: compact ? 0.46 : 0.68,
                            child: const _SkeletonBlock(height: 11, radius: 7),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              _SkeletonBlock(width: 72, height: 22, radius: 99),
                              SizedBox(width: 8),
                              _SkeletonBlock(width: 92, height: 22, radius: 99),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OcgSkeletonBox extends StatelessWidget {
  const OcgSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _OcgShimmer(
      child: _SkeletonBlock(width: width, height: height, radius: radius),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9DED3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _OcgShimmer extends StatefulWidget {
  const _OcgShimmer({required this.child});

  final Widget child;

  @override
  State<_OcgShimmer> createState() => _OcgShimmerState();
}

class _OcgShimmerState extends State<_OcgShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE9DED3),
                Color(0xFFF9F4EE),
                Color(0xFFE9DED3),
              ],
              stops: const [0.18, 0.50, 0.82],
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.value);

  final double value;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (value * 2 - 1), 0, 0);
  }
}
