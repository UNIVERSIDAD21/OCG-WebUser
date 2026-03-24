import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class PatientHeader extends StatelessWidget {
  const PatientHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: OcgColors.ivory,
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: OcgColors.espresso,
            ),
          ),
          const Spacer(),
          TextButton.icon(onPressed: () {}, icon: const Icon(Icons.help_outline), label: const Text('Ayuda')),
        ],
      ),
    );
  }
}
