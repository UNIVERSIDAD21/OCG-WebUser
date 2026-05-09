import 'package:flutter/material.dart';

class OcgEmptyState extends StatefulWidget {
  const OcgEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  @override
  State<OcgEmptyState> createState() => _OcgEmptyStateState();
}

class _OcgEmptyStateState extends State<OcgEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fadeSlide = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
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
    final hasCta = widget.ctaLabel != null && widget.onCta != null;
    final hasSecondary =
        widget.secondaryCtaLabel != null && widget.onSecondaryCta != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated icon ──
                Transform.scale(
                  scale: _pulse.value,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFC8AF8C).withOpacity(0.2),
                          const Color(0xFFB49B78).withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD9CCBE).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF8A6F59),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ──
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2C2016),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.3,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A6F59),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],

                // ── CTAs ──
                if (hasCta || hasSecondary) ...[
                  const SizedBox(height: 22),
                  if (hasCta)
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: widget.onCta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2016),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                        ),
                        child: Text(
                          widget.ctaLabel!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  if (hasSecondary) ...[
                    if (hasCta) const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: widget.onSecondaryCta,
                        child: Text(
                          widget.secondaryCtaLabel!,
                          style: const TextStyle(
                            color: Color(0xFF6E5442),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
