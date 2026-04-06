import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';

class PatientNavItem {
  const PatientNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class PatientBottomNav extends StatelessWidget {
  const PatientBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PatientNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFECD9C6))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142C2016),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 6),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                item: items[i],
                active: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final PatientNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = active ? item.selectedIcon : item.icon;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2.5,
              width: 24,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: active ? OcgColors.espresso : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF2EDE8) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: active ? OcgColors.espresso : const Color(0xFF8A6F59),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? OcgColors.espresso : const Color(0xFF8A6F59),
                letterSpacing: 0.1,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
