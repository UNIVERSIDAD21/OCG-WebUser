import 'package:flutter/material.dart';

class ActionToolbar extends StatelessWidget {
  const ActionToolbar({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}
