import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: OcgColors.bronze),
          if (icon != null) const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: OcgColors.espresso)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: OcgColors.ink.withOpacity(0.72))),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: OcgColors.ink.withOpacity(0.6))),
          ],
        ],
      ),
    );
  }
}
