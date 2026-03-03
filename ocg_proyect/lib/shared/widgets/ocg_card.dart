import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgCard extends StatelessWidget {
  const OcgCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1A2C2016)),
      ),
      child: child,
    );
  }
}
