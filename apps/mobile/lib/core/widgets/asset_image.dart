import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/dark_colors.dart';
import 'skeleton.dart';

/// True when [path] points at a remote resource rather than a bundled
/// asset. Shared by widgets that accept "asset path or URL" image
/// references (covers, avatars).
bool isRemoteImage(String? path) =>
    path != null &&
    (path.startsWith('http://') || path.startsWith('https://'));

/// Image widget that gracefully falls back to a default placeholder when the
/// requested image is missing or fails to load.
///
/// Accepts a bundled asset path (`assets/...`) or a remote URL (Firebase
/// Storage download URL from `ActivityRecord.coverImageUrl` /
/// `UserRecord.photoUrl`). Used across activity detail / list screens so
/// that a missing cover image or avatar never breaks the layout — instead
/// a neutral branded placeholder is shown.
class AssetImageWithFallback extends StatelessWidget {
  const AssetImageWithFallback({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.borderRadius,
    this.placeholderColor,
    this.placeholderIcon = Icons.image_outlined,
    this.isAvatar = false,
  });

  /// Bundled asset path (e.g. `assets/images/discovery/covers/foo.png`)
  /// or remote `http(s)` URL.
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  /// Defaults to `context.colors.divider` (theme-aware) when null.
  final Color? placeholderColor;
  final IconData placeholderIcon;

  /// When true, the placeholder is rendered as a circle with a person icon,
  /// which is the right default for avatar tiles.
  final bool isAvatar;

  @override
  Widget build(BuildContext context) {
    final resolvedPlaceholderColor = placeholderColor ?? context.colors.divider;
    final placeholder = isAvatar
        ? _AvatarPlaceholder(
            size: width ?? height,
            color: resolvedPlaceholderColor,
          )
        : _CoverPlaceholder(
            width: width,
            height: height,
            color: resolvedPlaceholderColor,
            icon: placeholderIcon,
          );

    // Remote images stream in over the network: show the branded shimmer
    // sweep while bytes arrive, then cross-fade the photo in. Bundled
    // assets resolve synchronously, so they render directly with no
    // loader (and no animation that could perturb golden tests).
    final image = isRemoteImage(imagePath)
        ? Image.network(
            imagePath,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: semanticLabel,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : SkeletonBox(
                    width: width,
                    height: height ?? 200,
                    radius: isAvatar ? (width ?? height ?? 44) / 2 : 0,
                  ),
            frameBuilder: (context, child, frame, sync) {
              if (sync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AppDurations.base,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) => placeholder,
          )
        : Image.asset(
            imagePath,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: semanticLabel,
            errorBuilder: (context, error, stackTrace) => placeholder,
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
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
      child: Icon(icon, size: h * 0.3, color: context.colors.textSecondary),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size, required this.color});

  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 32;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: s * 0.6,
        color: context.colors.textSecondary,
      ),
    );
  }
}
