import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

class OcgLoadingScreen extends StatefulWidget {
  const OcgLoadingScreen({super.key});

  @override
  State<OcgLoadingScreen> createState() => _OcgLoadingScreenState();
}

class _OcgLoadingScreenState extends State<OcgLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcgColors.ivory,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'OCG',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: OcgColors.espresso,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ORTODONCIA CUÉLLAR GRIMALDI',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: Color(0xFF8A6F59),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Container(
                width: 140,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [
                      OcgColors.sand,
                      OcgColors.bronze.withValues(
                        alpha: 0.35 + (_controller.value * 0.6),
                      ),
                      OcgColors.sand,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
