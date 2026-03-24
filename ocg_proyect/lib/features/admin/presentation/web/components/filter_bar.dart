import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    this.onSearch,
    this.hintText = 'Buscar...',
    this.trailing,
  });

  final ValueChanged<String>? onSearch;
  final String hintText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: OcgColors.ivory,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
