import 'package:flutter/material.dart';

class WebPageContainer extends StatelessWidget {
  const WebPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1400,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width >= 1500
        ? 24.0
        : width >= 1200
            ? 20.0
            : 14.0;
    final vertical = width >= 1200 ? 20.0 : 14.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding == const EdgeInsets.all(20)
              ? EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical)
              : padding,
          child: child,
        ),
      ),
    );
  }
}
