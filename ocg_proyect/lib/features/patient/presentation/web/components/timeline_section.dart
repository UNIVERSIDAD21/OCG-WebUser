import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class TimelineSection extends StatelessWidget {
  const TimelineSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
