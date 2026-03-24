import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: OcgColors.bronze),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: OcgColors.ink.withOpacity(0.65), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
