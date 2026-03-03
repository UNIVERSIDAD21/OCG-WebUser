import 'package:flutter/material.dart';

import 'ocg_button.dart';

class OcgEmptyState extends StatelessWidget {
  const OcgEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16),
              OcgButton(label: ctaLabel!, onPressed: onCta),
            ]
          ],
        ),
      ),
    );
  }
}
