import 'package:flutter/widgets.dart';

class WebBreakpoints {
  static const double mobileMax = 799;
  static const double desktopMin = 900;
  static const double compactDesktopMax = 1279;
  static const double comfortableDesktopMax = 1599;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopMin;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > mobileMax && w < desktopMin;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMax;

  static bool isCompactDesktop(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= desktopMin && w <= compactDesktopMax;
  }

  static bool isComfortableDesktop(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > compactDesktopMax && w <= comfortableDesktopMax;
  }

  static double shellMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1680) return 1440;
    if (width >= 1440) return 1320;
    if (width >= desktopMin) return 1180;
    return width;
  }

  static double shellHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1680) return 24;
    if (width >= 1440) return 20;
    if (width >= desktopMin) return 16;
    return 12;
  }
}
