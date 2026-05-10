import 'package:flutter/material.dart';

import '../../../../../presentation/web/common/web_breakpoints.dart';
import '../../../../../shared/theme/ocg_colors.dart';

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final compact = WebBreakpoints.isCompactDesktop(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.ink.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Cuando el padre da altura infinita (ej. dentro de scrollable),
          // NO podemos usar Expanded ni Flexible. En ese caso dejamos que
          // el hijo se mida con altura libre.
          final hasBoundedHeight = constraints.maxHeight < double.infinity;

          return Column(
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
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              if (expandChild && hasBoundedHeight)
                Expanded(child: child)
              else
                child,
            ],
          );
        },
      ),
    );
  }
}
