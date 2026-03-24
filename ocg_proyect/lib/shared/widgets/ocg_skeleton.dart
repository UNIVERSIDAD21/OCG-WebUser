import 'package:flutter/material.dart';

class OcgSkeletonList extends StatelessWidget {
  const OcgSkeletonList({super.key, this.items = 3});

  final int items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xFFF1ECE5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
