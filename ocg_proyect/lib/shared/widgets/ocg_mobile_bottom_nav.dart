import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgMobileBottomNavItem {
  const OcgMobileBottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class OcgMobileBottomNav extends StatelessWidget {
  const OcgMobileBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<OcgMobileBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Container(
          color: OcgColors.ivory,
          padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _OcgMobileBottomNavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcgMobileBottomNavButton extends StatelessWidget {
  const _OcgMobileBottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OcgMobileBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? OcgColors.ivory
        : OcgColors.bronze.withOpacity(0.68);
    final textColor = selected
        ? OcgColors.espresso
        : OcgColors.ink.withOpacity(0.52);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 50 : 42,
                height: 34,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [OcgColors.espresso, OcgColors.bronze],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : OcgColors.sand.withOpacity(0.34),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? OcgColors.ivory.withOpacity(0.32)
                        : OcgColors.bronze.withOpacity(0.12),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey('${item.label}-$selected'),
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  height: 1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: selected ? 0.1 : 0,
                ),
                child: Text(item.label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
