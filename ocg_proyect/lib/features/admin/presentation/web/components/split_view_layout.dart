import 'package:flutter/material.dart';

class SplitViewLayout extends StatelessWidget {
  const SplitViewLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 4,
    this.rightFlex = 7,
    this.gap = 12,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: gap),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
