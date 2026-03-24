import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class HighlightCard extends StatelessWidget {
  const HighlightCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 980;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.ink.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing case final t) t,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
