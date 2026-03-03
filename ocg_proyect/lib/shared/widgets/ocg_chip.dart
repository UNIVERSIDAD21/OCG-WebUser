import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgChip extends StatelessWidget {
  const OcgChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('completado')) {
      bg = OcgColors.success.withValues(alpha:0.14);
      fg = OcgColors.success;
    } else if (lower.contains('activo') || lower.contains('curso')) {
      bg = OcgColors.bronze.withValues(alpha:0.18);
      fg = OcgColors.espresso;
    } else if (lower.contains('pendiente')) {
      bg = OcgColors.warning.withValues(alpha:0.18);
      fg = OcgColors.warning;
    } else {
      bg = OcgColors.error.withValues(alpha:0.16);
      fg = OcgColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
