import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Image widget that gracefully falls back to a default placeholder when the
/// requested asset is missing or fails to load.
///
/// Used across activity detail / list screens so that a missing cover image or
/// avatar never breaks the layout — instead a neutral branded placeholder is
/// shown.
class AssetImageWithFallback extends StatelessWidget {
  const AssetImageWithFallback({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.borderRadius,
    this.placeholderColor = const Color(0xFFE5E7EB),
    this.placeholderIcon = Icons.image_outlined,
    this.isAvatar = false,
  });

  /// Path to the asset image (e.g. `assets/images/discovery/covers/foo.png`).
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final IconData placeholderIcon;

  /// When true, the placeholder is rendered as a circle with a person icon,
  /// which is the right default for avatar tiles.
  final bool isAvatar;

  @override
  Widget build(BuildContext context) {
    final placeholder = isAvatar
        ? _AvatarPlaceholder(
            size: width ?? height,
            color: placeholderColor,
          )
        : _CoverPlaceholder(
            width: width,
            height: height,
            color: placeholderColor,
            icon: placeholderIcon,
          );

    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }
    return image;
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.width,
    required this.height,
    required this.color,
    required this.icon,
  });

  final double? width;
  final double? height;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final h = height ?? 120;
    return Container(
      width: width,
      height: height,
      color: color,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: h * 0.3,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({
    required this.size,
    required this.color,
  });

  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 32;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: s * 0.6,
        color: AppColors.textSecondary,
      ),
    );
  }
}
