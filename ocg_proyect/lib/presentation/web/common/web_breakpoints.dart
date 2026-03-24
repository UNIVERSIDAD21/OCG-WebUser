import 'package:flutter/widgets.dart';

class WebBreakpoints {
  static const double mobileMax = 799;
  static const double tabletMax = 1199;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > tabletMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > mobileMax && w <= tabletMax;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMax;
}
