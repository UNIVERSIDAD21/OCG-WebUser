import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

enum OcgButtonVariant { primary, outline, ghost }

class OcgButton extends StatelessWidget {
  const OcgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = OcgButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final OcgButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: OcgColors.ivory),
          )
        else if (icon != null)
          Icon(icon, size: 16),
        if (isLoading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    switch (variant) {
      case OcgButtonVariant.primary:
        return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : onPressed, child: child));
      case OcgButtonVariant.outline:
        return SizedBox(width: double.infinity, child: OutlinedButton(onPressed: isLoading ? null : onPressed, child: child));
      case OcgButtonVariant.ghost:
        return SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(foregroundColor: OcgColors.espresso),
            child: child,
          ),
        );
    }
  }
}
