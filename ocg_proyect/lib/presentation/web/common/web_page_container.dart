import 'package:flutter/material.dart';

class WebPageContainer extends StatelessWidget {
  const WebPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1400,
    this.padding = const EdgeInsets.all(20),
    this.expandHeight = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (expandHeight) {
      return SizedBox.expand(
        child: Align(
          alignment: Alignment.topCenter,
          child: content,
        ),
      );
    }

    return Center(child: content);
  }
}
