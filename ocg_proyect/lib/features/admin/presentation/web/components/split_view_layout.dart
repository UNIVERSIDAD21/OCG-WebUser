import 'package:flutter/material.dart';

import '../layout/admin_desktop_layout.dart';

class SplitViewLayout extends StatelessWidget {
  const SplitViewLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 4,
    this.rightFlex = 7,
    this.gap,
    this.primaryMinWidth,
    this.secondaryMinWidth,
    this.stackWhenTight = true,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double? gap;
  final double? primaryMinWidth;
  final double? secondaryMinWidth;
  final bool stackWhenTight;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.maybeOf(context);
    final resolvedGap = gap ?? layout?.panelGap ?? 12;
    final keepSplit =
        layout?.shouldKeepSplit(
          primaryMinWidth: primaryMinWidth,
          secondaryMinWidth: secondaryMinWidth,
          gap: resolvedGap,
        ) ??
        true;

    if (!keepSplit && stackWhenTight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: resolvedGap),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: resolvedGap),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
