import 'package:flutter/material.dart';

class OcgTextField extends StatelessWidget {
  const OcgTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.errorText,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? errorText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}
