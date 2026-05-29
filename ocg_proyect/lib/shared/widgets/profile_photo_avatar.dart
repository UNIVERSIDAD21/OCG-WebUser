import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';
import 'ocg_cached_image.dart';

class ProfilePhotoAvatar extends StatelessWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.label,
    this.photoUrl,
    this.radius = 42,
    this.loading = false,
    this.onChange,
    this.onDelete,
    this.showActions = false,
  });

  final String label;
  final String? photoUrl;
  final double radius;
  final bool loading;
  final VoidCallback? onChange;
  final VoidCallback? onDelete;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = photoUrl?.trim();
    final hasPhoto = cleanUrl != null && cleanUrl.isNotEmpty;
    final avatar = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: hasPhoto
            ? OcgCachedImage(
                imageUrl: cleanUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2).round(),
                memCacheHeight: (radius * 2).round(),
                errorWidget: _InitialsAvatar(label: label, radius: radius),
              )
            : _InitialsAvatar(label: label, radius: radius),
      ),
    );

    if (!showActions) return avatar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatar,
            CircleAvatar(
              radius: 17,
              backgroundColor: OcgColors.bronze,
              child: IconButton(
                onPressed: loading ? null : onChange,
                icon: loading
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OcgColors.ivory,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 15,
                        color: OcgColors.ivory,
                      ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 22, minWidth: 22),
                tooltip: 'Cambiar foto',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: loading ? null : onChange,
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: const Text('Cambiar foto'),
            ),
            if (hasPhoto)
              TextButton.icon(
                onPressed: loading ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(foregroundColor: OcgColors.error),
              ),
          ],
        ),
      ],
    );
  }

  static String initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.label, required this.radius});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: OcgColors.bronze.withValues(alpha: 0.18),
      child: Text(
        ProfilePhotoAvatar.initials(label),
        style: TextStyle(
          fontSize: radius * 0.45,
          fontWeight: FontWeight.w800,
          color: OcgColors.espresso,
        ),
      ),
    );
  }
}
