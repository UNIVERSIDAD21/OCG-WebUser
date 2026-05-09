import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OcgAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(4, topPad + 4, 8, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2016), Color(0xFF4A3628)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: OcgColors.ivory,
                size: 18,
              ),
            )
          else
            const SizedBox(width: 8),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: OcgColors.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
