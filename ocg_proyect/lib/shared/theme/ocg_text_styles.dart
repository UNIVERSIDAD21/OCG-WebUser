import 'package:flutter/material.dart';

import 'ocg_colors.dart';

class OcgTextStyles {
  OcgTextStyles._();

  static const TextStyle display = TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: OcgColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: OcgColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    color: OcgColors.ink,
  );
}
