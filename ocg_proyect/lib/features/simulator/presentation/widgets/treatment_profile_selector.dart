import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../domain/dental_treatment_profile.dart';

/// Dropdown selector for treatment profiles.
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
    final selectedProfile = selectedProfileId == null
        ? null
        : lookupProfile(selectedProfileId!);
    final selectedValue = selectedProfile?.id;
    final accent = selectedProfile?.color ?? OcgColors.bronze;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 4),
      decoration: BoxDecoration(
        color: selectedProfile == null
            ? OcgColors.ivory
            : accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedProfile == null
              ? OcgColors.bronze.withOpacity(0.22)
              : accent.withOpacity(0.36),
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: const Color(0xFFFFFBF8),
          menuMaxHeight: compact ? 330 : 420,
          itemHeight: compact ? 62 : 70,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
          hint: _SelectorHint(compact: compact),
          selectedItemBuilder: (context) {
            return treatmentProfiles
                .map(
                  (profile) =>
                      _SelectedProfileRow(profile: profile, compact: compact),
                )
                .toList();
          },
          items: treatmentProfiles.map((profile) {
            return DropdownMenuItem<String>(
              value: profile.id,
              child: _ProfileOptionRow(
                profile: profile,
                compact: compact,
                isSelected: profile.id == selectedValue,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) onSelected(id);
          },
        ),
      ),
    );
  }
}

class _SelectorHint extends StatelessWidget {
  const _SelectorHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: OcgColors.bronze.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OcgColors.bronze.withOpacity(0.18)),
          ),
          child: const Icon(
            Icons.format_list_bulleted_rounded,
            color: OcgColors.bronze,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Selecciona un tratamiento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: OcgColors.bronze,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedProfileRow extends StatelessWidget {
  const _SelectedProfileRow({required this.profile, required this.compact});

  final DentalTreatmentProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfileIconBadge(profile: profile, compact: compact, filled: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileOptionRow extends StatelessWidget {
  const _ProfileOptionRow({
    required this.profile,
    required this.compact,
    required this.isSelected,
  });

  final DentalTreatmentProfile profile;
  final bool compact;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? profile.color.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? profile.color.withOpacity(0.28)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          _ProfileIconBadge(profile: profile, compact: compact),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OcgColors.ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: profile.color, size: 18),
          ],
        ],
      ),
    );
  }
}

class _ProfileIconBadge extends StatelessWidget {
  const _ProfileIconBadge({
    required this.profile,
    required this.compact,
    this.filled = false,
  });

  final DentalTreatmentProfile profile;
  final bool compact;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? profile.color : profile.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: profile.color.withOpacity(0.28)),
      ),
      child: Icon(
        profile.icon,
        size: compact ? 18 : 20,
        color: filled ? Colors.white : profile.color,
      ),
    );
  }
}
