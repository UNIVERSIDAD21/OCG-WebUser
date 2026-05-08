import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgHeroMetric {
  const OcgHeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class OcgHeroHeader extends StatelessWidget {
  const OcgHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metrics,
    this.gradientColors = const [Color(0xFF4A3527), Color(0xFF9A7654)],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<OcgHeroMetric> metrics;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: OcgColors.ivory),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFEADFD4),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  Expanded(child: _OcgHeroMetricTile(metric: metrics[index])),
                  if (index != metrics.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OcgHeroMetricTile extends StatelessWidget {
  const _OcgHeroMetricTile({required this.metric});

  final OcgHeroMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OcgColors.ivory.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            metric.icon,
            size: 16,
            color: OcgColors.ivory.withValues(alpha: 0.78),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            metric.label,
            style: TextStyle(
              color: OcgColors.ivory.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OcgStatusPill extends StatelessWidget {
  const OcgStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.highlighted = false,
    this.compact = true,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact ? 8.0 : 10.0;
    final vertical = compact ? 5.0 : 6.0;
    final fontSize = compact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlighted ? 0.13 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 0.20 : 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OcgPremiumEmptyState extends StatelessWidget {
  const OcgPremiumEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: OcgColors.bronze),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OcgColors.bronze, height: 1.3),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
