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
  late String? _expandedGroupId;

  @override
  void initState() {
    super.initState();
    _expandedGroupId = _groupIdForProfile(widget.selectedProfileId);
  }

  @override
  void didUpdateWidget(covariant TreatmentProfileSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProfileId != oldWidget.selectedProfileId) {
      final selectedGroupId = _groupIdForProfile(widget.selectedProfileId);
      if (selectedGroupId != null && selectedGroupId != _expandedGroupId) {
        _expandedGroupId = selectedGroupId;
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

  void _toggleGroup(String groupId) {
    setState(() {
      _expandedGroupId = _expandedGroupId == groupId ? null : groupId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile = widget.selectedProfileId == null
        ? null
        : lookupProfile(widget.selectedProfileId!);
    final selectedProfileId = selectedProfile?.id ?? widget.selectedProfileId;

    return Column(
      children: [
        for (var i = 0; i < treatmentGroups.length; i++) ...[
          _TreatmentGroupPanel(
            group: treatmentGroups[i],
            compact: widget.compact,
            expanded: treatmentGroups[i].id == _expandedGroupId,
            selectedProfileId: selectedProfileId,
            onToggle: () => _toggleGroup(treatmentGroups[i].id),
            onSelected: widget.onSelected,
          ),
          if (i != treatmentGroups.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _TreatmentGroupPanel extends StatelessWidget {
  const _TreatmentGroupPanel({
    required this.group,
    required this.compact,
    required this.expanded,
    required this.selectedProfileId,
    required this.onToggle,
    required this.onSelected,
  });

  final TreatmentGroup group;
  final bool compact;
  final bool expanded;
  final String? selectedProfileId;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasSelectedProfile = group.treatments.any(
      (profile) => profile.id == selectedProfileId,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: expanded || hasSelectedProfile
            ? group.color.withOpacity(0.06)
            : OcgColors.ivory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded || hasSelectedProfile
              ? group.color.withOpacity(0.26)
              : OcgColors.bronze.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(expanded ? 0.06 : 0.035),
            blurRadius: expanded ? 16 : 10,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            _TreatmentGroupHeader(
              group: group,
              compact: compact,
              expanded: expanded,
              onTap: onToggle,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? _TreatmentCardsGrid(
                        treatments: group.treatments,
                        compact: compact,
                        selectedProfileId: selectedProfileId,
                        onSelected: onSelected,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreatmentGroupHeader extends StatelessWidget {
  const _TreatmentGroupHeader({
    required this.group,
    required this.compact,
    required this.expanded,
    required this.onTap,
  });

  final TreatmentGroup group;
  final bool compact;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              decoration: BoxDecoration(
                color: group.color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: group.color.withOpacity(0.26)),
              ),
              child: Icon(
                group.icon,
                color: group.color,
                size: compact ? 16 : 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OcgColors.espresso,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _TreatmentCountBadge(
              count: group.treatments.length,
              color: group.color,
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: group.color,
                size: 22,
              ),
            ),
          ],
        ),
      ),
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
        final horizontalPadding = compact ? 20.0 : 24.0;
        final innerWidth = constraints.maxWidth - horizontalPadding;
        final width = columns == 1
            ? innerWidth
            : (innerWidth - spacing) / columns;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            0,
            compact ? 10 : 12,
            compact ? 10 : 12,
          ),
          child: Wrap(
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
          ),
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
