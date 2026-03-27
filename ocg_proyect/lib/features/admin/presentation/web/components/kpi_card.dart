import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.footnote,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 165;

        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: OcgColors.ivory,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: OcgColors.bronze, size: compact ? 20 : 22),
              SizedBox(height: compact ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: compact ? 21 : 24,
                          fontWeight: FontWeight.w700,
                          color: OcgColors.espresso,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: OcgColors.ink.withOpacity(0.65),
                        fontSize: compact ? 11 : 12,
                        height: 1.2,
                      ),
                    ),
                    if (footnote != null && footnote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        footnote!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: OcgColors.success,
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
