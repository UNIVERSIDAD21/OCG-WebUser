import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

ImageProvider? ocgCachedImageProvider(String? url) {
  final cleanUrl = url?.trim();
  if (cleanUrl == null || cleanUrl.isEmpty) return null;
  return CachedNetworkImageProvider(cleanUrl);
}

class OcgCachedImage extends StatelessWidget {
  const OcgCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.cacheKey,
    this.filterQuality = FilterQuality.medium,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? cacheKey;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim();
    final fallback =
        errorWidget ??
        _DefaultCachedImageFallback(width: width, height: height);
    if (cleanUrl == null || cleanUrl.isEmpty) return fallback;

    final image = CachedNetworkImage(
      imageUrl: cleanUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      filterQuality: filterQuality,
      fadeInDuration: const Duration(milliseconds: 160),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) =>
          placeholder ??
          _DefaultCachedImagePlaceholder(width: width, height: height),
      errorWidget: (_, __, ___) => fallback,
    );

    final radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}

class _DefaultCachedImagePlaceholder extends StatelessWidget {
  const _DefaultCachedImagePlaceholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: const Color(0xFFF6EFE7),
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: OcgColors.bronze.withOpacity(0.72),
      ),
    );
  }
}

class _DefaultCachedImageFallback extends StatelessWidget {
  const _DefaultCachedImageFallback({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: const Color(0xFFF6EFE7),
      child: const Icon(Icons.broken_image_outlined, color: OcgColors.bronze),
    );
  }
}
