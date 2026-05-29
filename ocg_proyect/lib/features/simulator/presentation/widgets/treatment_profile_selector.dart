import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../domain/dental_treatment_profile.dart';

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
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId =
        _groupIdForProfile(widget.selectedProfileId) ??
        treatmentGroups.first.id;
  }

  @override
  void didUpdateWidget(covariant TreatmentProfileSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProfileId != oldWidget.selectedProfileId) {
      final selectedGroupId = _groupIdForProfile(widget.selectedProfileId);
      if (selectedGroupId != null && selectedGroupId != _selectedGroupId) {
        _selectedGroupId = selectedGroupId;
      }
    }
  }

  static String? _groupIdForProfile(String? profileId) {
    if (profileId == null || profileId.isEmpty) return null;
    final normalizedId = lookupProfile(profileId)?.id ?? profileId;
    for (final group in treatmentGroups) {
      if (group.treatments.any((profile) => profile.id == normalizedId)) {
        return group.id;
      }
    }
    return null;
  }

  TreatmentGroup get _activeGroup {
    return treatmentGroups.firstWhere(
      (group) => group.id == _selectedGroupId,
      orElse: () => treatmentGroups.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile = widget.selectedProfileId == null
        ? null
        : lookupProfile(widget.selectedProfileId!);
    final selectedProfileId = selectedProfile?.id ?? widget.selectedProfileId;
    final activeGroup = _activeGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupDropdown(
          group: activeGroup,
          compact: widget.compact,
          onSelected: (group) {
            setState(() => _selectedGroupId = group.id);
          },
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: _TreatmentCardsGrid(
            key: ValueKey(activeGroup.id),
            treatments: activeGroup.treatments,
            compact: widget.compact,
            selectedProfileId: selectedProfileId,
            onSelected: widget.onSelected,
          ),
        ),
      ],
    );
  }
}

class _GroupDropdown extends StatefulWidget {
  const _GroupDropdown({
    required this.group,
    required this.compact,
    required this.onSelected,
  });

  final TreatmentGroup group;
  final bool compact;
  final ValueChanged<TreatmentGroup> onSelected;

  @override
  State<_GroupDropdown> createState() => _GroupDropdownState();
}

class _GroupDropdownState extends State<_GroupDropdown> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFFFFFBF8)),
        maximumSize: WidgetStateProperty.all(
          Size.fromHeight(widget.compact ? 340 : 420),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: OcgColors.bronze.withOpacity(0.14)),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
      menuChildren: treatmentGroups.map((group) {
        return MenuItemButton(
          onPressed: () {
            widget.onSelected(group);
            _controller.close();
          },
          child: _GroupOptionRow(
            group: group,
            compact: widget.compact,
            isSelected: group.id == widget.group.id,
          ),
        );
      }).toList(),
      child: InkWell(
        onTap: () {
          if (_controller.isOpen) {
            _controller.close();
          } else {
            _controller.open();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 12,
            vertical: widget.compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: widget.group.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.group.color.withOpacity(0.26)),
            boxShadow: [
              BoxShadow(
                color: OcgColors.espresso.withOpacity(0.045),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _GroupIcon(group: widget.group, compact: widget.compact),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.compact ? 13 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TreatmentCountBadge(
                count: widget.group.treatments.length,
                color: widget.group.color,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: widget.group.color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupOptionRow extends StatelessWidget {
  const _GroupOptionRow({
    required this.group,
    required this.compact,
    required this.isSelected,
  });

  final TreatmentGroup group;
  final bool compact;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: isSelected ? group.color.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? group.color.withOpacity(0.24)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          _GroupIcon(group: group, compact: compact),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TreatmentCountBadge(
            count: group.treatments.length,
            color: group.color,
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: group.color, size: 18),
          ],
        ],
      ),
    );
  }
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.group, required this.compact});

  final TreatmentGroup group;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 36.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: group.color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: group.color.withOpacity(0.26)),
      ),
      child: Icon(group.icon, color: group.color, size: compact ? 17 : 19),
    );
  }
}

class _TreatmentCountBadge extends StatelessWidget {
  const _TreatmentCountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        '$count tratamientos',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TreatmentCardsGrid extends StatelessWidget {
  const _TreatmentCardsGrid({
    super.key,
    required this.treatments,
    required this.compact,
    required this.selectedProfileId,
    required this.onSelected,
  });

  final List<DentalTreatmentProfile> treatments;
  final bool compact;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact ? 1 : 2;
        final spacing = compact ? 8.0 : 10.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: treatments.map((profile) {
            return SizedBox(
              width: width,
              height: compact ? 150 : 168,
              child: _TreatmentProfileCard(
                profile: profile,
                compact: compact,
                isSelected: profile.id == selectedProfileId,
                onTap: () => onSelected(profile.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TreatmentProfileCard extends StatelessWidget {
  const _TreatmentProfileCard({
    required this.profile,
    required this.compact,
    required this.isSelected,
    required this.onTap,
  });

  final DentalTreatmentProfile profile;
  final bool compact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(compact ? 11 : 12),
        decoration: BoxDecoration(
          color: isSelected ? profile.color.withOpacity(0.08) : OcgColors.ivory,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? profile.color.withOpacity(0.4)
                : OcgColors.bronze.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 42 : 48,
                    height: compact ? 42 : 48,
                    decoration: BoxDecoration(
                      color: profile.color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: profile.color.withOpacity(0.24),
                      ),
                    ),
                    child: Icon(
                      profile.icon,
                      color: profile.color,
                      size: compact ? 22 : 25,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    profile.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      profile.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OcgColors.ink,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isSelected ? 1 : 0,
                    child: _SelectedBadge(color: profile.color),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: profile.color,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      alignment: Alignment.center,
      child: Text(
        'Seleccionado',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}
