import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: OcgColors.ink.withOpacity(0.7))),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
