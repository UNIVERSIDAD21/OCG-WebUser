import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class AppointmentHighlightCard extends StatelessWidget {
  const AppointmentHighlightCard({
    super.key,
    required this.title,
    required this.whenText,
    this.trailing,
  });

  final String title;
  final String whenText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, color: OcgColors.bronze),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: OcgColors.espresso)),
                Text(whenText),
              ],
            ),
          ),
          if (trailing case final t) t,
        ],
      ),
    );
  }
}
