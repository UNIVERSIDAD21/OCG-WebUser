import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../domain/dental_treatment_profile.dart';

/// Dynamic form that renders config fields based on the selected treatment profile.
class DoctorConfigForm extends StatelessWidget {
  const DoctorConfigForm({
    super.key,
    required this.profile,
    required this.config,
    required this.onChanged,
    this.enabled = true,
  });

  final DentalTreatmentProfile profile;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (profile.configFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuración',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: OcgColors.espresso,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...profile.configFields.map((field) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildField(context, field),
          );
        }),
      ],
    );
  }

  Widget _buildField(BuildContext context, TreatmentConfigField field) {
    final value =
        config[field.key]?.toString() ?? field.defaultValue?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: OcgColors.espresso,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        if (profile.id == 'metal_braces' && field.key == 'ligatureColor')
          _LigatureColorField(
            value: value,
            enabled: enabled,
            onChanged: (selected) {
              final updated = Map<String, dynamic>.from(config);
              updated[field.key] = selected;
              onChanged(updated);
            },
          )
        else if (field.type == TreatmentConfigFieldType.chips)
          _ChipsField(
            options: field.options,
            value: value,
            enabled: enabled,
            onChanged: (value) {
              final updated = Map<String, dynamic>.from(config);
              updated[field.key] = value;
              onChanged(updated);
            },
          )
        else if (field.type == TreatmentConfigFieldType.dropdown)
          _DropdownField(
            options: field.options,
            value: value,
            enabled: enabled,
            onChanged: (value) {
              final updated = Map<String, dynamic>.from(config);
              updated[field.key] = value;
              onChanged(updated);
            },
          ),
      ],
    );
  }
}

class _LigatureColorOption {
  const _LigatureColorOption({
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  bool get isTransparent => value == 'transparente';
}

const List<_LigatureColorOption> _ligatureColors = [
  _LigatureColorOption(
    value: '#9E9E9E',
    label: 'Gris',
    color: Color(0xFF9E9E9E),
  ),
  _LigatureColorOption(value: 'transparente', label: 'Transparente'),
  _LigatureColorOption(
    value: '#2196F3',
    label: 'Azul',
    color: Color(0xFF2196F3),
  ),
  _LigatureColorOption(
    value: '#F44336',
    label: 'Rojo',
    color: Color(0xFFF44336),
  ),
  _LigatureColorOption(
    value: '#673AB7',
    label: 'Morado',
    color: Color(0xFF673AB7),
  ),
  _LigatureColorOption(
    value: '#FF9800',
    label: 'Naranja',
    color: Color(0xFFFF9800),
  ),
  _LigatureColorOption(
    value: '#FFEB3B',
    label: 'Amarillo',
    color: Color(0xFFFFEB3B),
  ),
  _LigatureColorOption(
    value: '#4CAF50',
    label: 'Verde',
    color: Color(0xFF4CAF50),
  ),
  _LigatureColorOption(
    value: '#00BCD4',
    label: 'Cyan',
    color: Color(0xFF00BCD4),
  ),
  _LigatureColorOption(
    value: '#E91E63',
    label: 'Rosa',
    color: Color(0xFFE91E63),
  ),
  _LigatureColorOption(
    value: '#0D47A1',
    label: 'Azul oscuro',
    color: Color(0xFF0D47A1),
  ),
  _LigatureColorOption(
    value: '#009688',
    label: 'Teal',
    color: Color(0xFF009688),
  ),
  _LigatureColorOption(
    value: '#795548',
    label: 'Café',
    color: Color(0xFF795548),
  ),
  _LigatureColorOption(
    value: '#607D8B',
    label: 'Azul grisáceo',
    color: Color(0xFF607D8B),
  ),
  _LigatureColorOption(
    value: '#FFFFFF',
    label: 'Blanco',
    color: Color(0xFFFFFFFF),
  ),
  _LigatureColorOption(
    value: '#000000',
    label: 'Negro',
    color: Color(0xFF000000),
  ),
  _LigatureColorOption(
    value: '#8BC34A',
    label: 'Verde claro',
    color: Color(0xFF8BC34A),
  ),
  _LigatureColorOption(
    value: '#FFC107',
    label: 'Ámbar',
    color: Color(0xFFFFC107),
  ),
  _LigatureColorOption(
    value: '#CDDC39',
    label: 'Lima',
    color: Color(0xFFCDDC39),
  ),
  _LigatureColorOption(
    value: '#E65100',
    label: 'Naranja oscuro',
    color: Color(0xFFE65100),
  ),
  _LigatureColorOption(
    value: '#757575',
    label: 'Gris medio',
    color: Color(0xFF757575),
  ),
  _LigatureColorOption(
    value: '#9C27B0',
    label: 'Púrpura',
    color: Color(0xFF9C27B0),
  ),
  _LigatureColorOption(
    value: '#03A9F4',
    label: 'Azul claro',
    color: Color(0xFF03A9F4),
  ),
  _LigatureColorOption(
    value: '#D500F9',
    label: 'Fucsia',
    color: Color(0xFFD500F9),
  ),
  _LigatureColorOption(
    value: '#39FF14',
    label: 'Verde neón',
    color: Color(0xFF39FF14),
  ),
  _LigatureColorOption(
    value: '#FF5F1F',
    label: 'Naranja neón',
    color: Color(0xFFFF5F1F),
  ),
  _LigatureColorOption(
    value: '#81D4FA',
    label: 'Celeste',
    color: Color(0xFF81D4FA),
  ),
  _LigatureColorOption(
    value: '#B39DDB',
    label: 'Lavanda',
    color: Color(0xFFB39DDB),
  ),
  _LigatureColorOption(
    value: '#F8BBD0',
    label: 'Rosado claro',
    color: Color(0xFFF8BBD0),
  ),
  _LigatureColorOption(
    value: '#BBDEFB',
    label: 'Azul bebé',
    color: Color(0xFFBBDEFB),
  ),
];

String _normalizeLigatureColorValue(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('#')) return trimmed.toUpperCase();

  const aliases = <String, String>{
    'gris': '#9E9E9E',
    'azul': '#2196F3',
    'rojo': '#F44336',
    'morado': '#673AB7',
    'naranja': '#FF9800',
    'amarillo': '#FFEB3B',
    'verde': '#4CAF50',
    'cyan': '#00BCD4',
    'rosa': '#E91E63',
    'transparente': 'transparente',
  };

  return aliases[trimmed.toLowerCase()] ?? trimmed;
}

class _LigatureColorField extends StatelessWidget {
  const _LigatureColorField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = _normalizeLigatureColorValue(value);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _ligatureColors.map((option) {
          final isSelected = normalizedValue == option.value;
          return Tooltip(
            message: option.label,
            child: GestureDetector(
              onTap: enabled ? () => onChanged(option.value) : null,
              child: _LigatureColorCircle(
                option: option,
                isSelected: isSelected,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LigatureColorCircle extends StatelessWidget {
  const _LigatureColorCircle({required this.option, required this.isSelected});

  final _LigatureColorOption option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = option.color ?? Colors.transparent;
    final checkColor = option.isTransparent || color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: option.isTransparent ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.grey.shade300,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: OcgColors.espresso.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (option.isTransparent)
            const Positioned.fill(
              child: ClipOval(
                child: CustomPaint(painter: _TransparentCheckerPainter()),
              ),
            ),
          if (option.isTransparent)
            const Positioned.fill(
              child: CustomPaint(
                painter: _DashedCirclePainter(color: Color(0xFF8A8177)),
              ),
            ),
          if (isSelected)
            Icon(Icons.check_rounded, color: checkColor, size: 16),
        ],
      ),
    );
  }
}

class _TransparentCheckerPainter extends CustomPainter {
  const _TransparentCheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.0;
    final light = Paint()..color = const Color(0xFFF6F1EA);
    final dark = Paint()..color = const Color(0xFFD9D1C7);

    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final useDark = ((x / cell).floor() + (y / cell).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          useDark ? dark : light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.6;
    const dashCount = 16;
    const dashRadians = math.pi / 18;

    for (var i = 0; i < dashCount; i++) {
      final start = i * 2 * math.pi / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashRadians,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ChipsField extends StatelessWidget {
  const _ChipsField({
    required this.options,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<TreatmentConfigOption> options;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt.value == value;
        return GestureDetector(
          onTap: enabled ? () => onChanged(opt.value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? OcgColors.espresso : OcgColors.ivory,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: isSelected
                    ? OcgColors.espresso
                    : OcgColors.bronze.withOpacity(0.22),
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                color: isSelected ? OcgColors.ivory : OcgColors.espresso,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.options,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<TreatmentConfigOption> options;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.22)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.any((o) => o.value == value) ? value : null,
          isExpanded: true,
          isDense: true,
          disabledHint: Text(
            value,
            style: const TextStyle(color: OcgColors.espresso),
          ),
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.value,
              child: Text(opt.label, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
