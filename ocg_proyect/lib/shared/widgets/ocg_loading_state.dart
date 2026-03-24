import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgLoadingState extends StatelessWidget {
  const OcgLoadingState({
    super.key,
    this.label = 'Cargando...',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: OcgColors.ink.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }
}
