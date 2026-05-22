import 'package:flutter/material.dart';

import '../../domain/dental_treatment_profile.dart';

/// Grid selector of 8 treatment profiles.
class TreatmentProfileSelector extends StatelessWidget {
  const TreatmentProfileSelector({
    super.key,
    required this.selectedProfileId,
    required this.onSelected,
    this.compact = false,
  });

  final String? selectedProfileId;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: treatmentProfiles.map((profile) {
        final isSelected = profile.id == selectedProfileId;
        return _ProfileChip(
          profile: profile,
          isSelected: isSelected,
          compact: compact,
          onTap: () => onSelected(profile.id),
        );
      }).toList(),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.profile,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  final DentalTreatmentProfile profile;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? profile.color
        : profile.color.withOpacity(0.08);
    final fgColor = isSelected ? Colors.white : profile.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? profile.color
                : profile.color.withOpacity(0.18),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: profile.color.withOpacity(0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(profile.icon, size: compact ? 18 : 20, color: fgColor),
            const SizedBox(width: 8),
            if (!compact)
              Flexible(
                child: Text(
                  profile.label,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
