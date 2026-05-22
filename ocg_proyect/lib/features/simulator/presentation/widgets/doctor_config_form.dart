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
        if (field.type == TreatmentConfigFieldType.chips)
          _ChipsField(
            options: field.options,
            value: config[field.key]?.toString() ??
                field.defaultValue?.toString() ??
                '',
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
            value: config[field.key]?.toString() ??
                field.defaultValue?.toString() ??
                '',
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? OcgColors.espresso
                  : OcgColors.ivory,
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
          disabledHint: Text(value,
              style: const TextStyle(color: OcgColors.espresso)),
          onChanged:
              enabled ? (v) { if (v != null) onChanged(v); } : null,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.value,
              child: Text(opt.label,
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
