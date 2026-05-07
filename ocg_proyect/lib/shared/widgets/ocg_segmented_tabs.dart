import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgSegmentedTabItem<T> {
  const OcgSegmentedTabItem({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? badge;
}

class OcgSegmentedTabs<T> extends StatelessWidget {
  const OcgSegmentedTabs({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.height = 42,
    this.padding = const EdgeInsets.all(4),
    this.compact = false,
  });

  final List<OcgSegmentedTabItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final item = items[index];
            return OcgTabPill(
              label: item.label,
              icon: item.icon,
              badge: item.badge,
              selected: item.value == selectedValue,
              compact: compact,
              onTap: () => onChanged(item.value),
            );
          },
        ),
      ),
    );
  }
}

class OcgTabPill extends StatelessWidget {
  const OcgTabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.badge,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? OcgColors.ivory
        : OcgColors.espresso.withOpacity(0.74);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [OcgColors.espresso, Color(0xFF9B7453)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected ? null : const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? OcgColors.bronze.withOpacity(0.42)
              : OcgColors.bronze.withOpacity(0.15),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: OcgColors.espresso.withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 7 : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 15 : 16, color: fg),
                  const SizedBox(width: 6),
                ],
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    color: fg,
                    fontSize: compact ? 12 : 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1,
                  ),
                  child: Text(label),
                ),
                if (badge != null && badge!.trim().isNotEmpty) ...[
                  const SizedBox(width: 7),
                  OcgTabBadge(label: badge!, selected: selected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OcgTabBadge extends StatelessWidget {
  const OcgTabBadge({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? OcgColors.ivory.withOpacity(0.20)
            : OcgColors.bronze.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? OcgColors.ivory.withOpacity(0.24)
              : OcgColors.bronze.withOpacity(0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? OcgColors.ivory : OcgColors.bronze,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
