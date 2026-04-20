import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  CurrencyInputFormatter({this.thousandsSeparator = '.'});

  final String thousandsSeparator;

  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  static double? parseToDouble(String input) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  static String formatDigits(String input, {String thousandsSeparator = '.'}) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return '';

    final chars = digits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(thousandsSeparator);
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDigits(
      newValue.text,
      thousandsSeparator: thousandsSeparator,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
