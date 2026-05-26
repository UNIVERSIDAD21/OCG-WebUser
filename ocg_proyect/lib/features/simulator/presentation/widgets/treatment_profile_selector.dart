import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../domain/dental_treatment_profile.dart';

/// Dropdown selector for treatment profiles.
/// Usa MenuAnchor para garantizar que el menú siempre abra hacia abajo.
class TreatmentProfileSelector extends StatefulWidget {
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
  State<TreatmentProfileSelector> createState() =>
      _TreatmentProfileSelectorState();
}

class _TreatmentProfileSelectorState extends State<TreatmentProfileSelector> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final selectedProfile = widget.selectedProfileId == null
        ? null
        : lookupProfile(widget.selectedProfileId!);
    final accent = selectedProfile?.color ?? OcgColors.bronze;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: 4,
      ),
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
      child: MenuAnchor(
        controller: _controller,
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFFFFFBF8)),
          maximumSize: WidgetStateProperty.all(
            Size.fromHeight(widget.compact ? 330 : 420),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: accent.withOpacity(0.15),
              ),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        menuChildren: treatmentProfiles.map((profile) {
          final isSelected = profile.id == widget.selectedProfileId;
          return MenuItemButton(
            onPressed: () {
              widget.onSelected(profile.id);
              _controller.close();
            },
            child: _ProfileOptionRow(
              profile: profile,
              compact: widget.compact,
              isSelected: isSelected,
            ),
          );
        }).toList(),
        child: SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: () {
              if (_controller.isOpen) {
                _controller.close();
              } else {
                _controller.open();
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _SelectorDisplay(
                selectedProfile: selectedProfile,
                accent: accent,
                compact: widget.compact,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorDisplay extends StatelessWidget {
  const _SelectorDisplay({
    required this.selectedProfile,
    required this.accent,
    required this.compact,
  });

  final DentalTreatmentProfile? selectedProfile;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: selectedProfile == null
                ? OcgColors.bronze.withOpacity(0.12)
                : accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selectedProfile == null
                  ? OcgColors.bronze.withOpacity(0.18)
                  : accent.withOpacity(0.28),
            ),
          ),
          child: Icon(
            selectedProfile?.icon ?? Icons.format_list_bulleted_rounded,
            color: selectedProfile == null ? OcgColors.bronze : accent,
            size: compact ? 18 : 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            selectedProfile?.label ?? 'Selecciona un tratamiento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selectedProfile == null ? OcgColors.bronze : OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: selectedProfile == null ? 13 : 14,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          color: accent,
          size: 20,
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
  });

  final DentalTreatmentProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: profile.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: profile.color.withOpacity(0.28)),
      ),
      child: Icon(
        profile.icon,
        size: compact ? 18 : 20,
        color: profile.color,
      ),
    );
  }
}
