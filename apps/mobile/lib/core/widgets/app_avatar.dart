import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Sizes for [AppAvatar].
enum AppAvatarSize { xs, sm, md, lg, xl }

extension _AvatarSizeX on AppAvatarSize {
  double get diameter => switch (this) {
        AppAvatarSize.xs => 24,
        AppAvatarSize.sm => 32,
        AppAvatarSize.md => 44,
        AppAvatarSize.lg => 56,
        AppAvatarSize.xl => 80,
      };
  double get fontSize => switch (this) {
        AppAvatarSize.xs => 10,
        AppAvatarSize.sm => 12,
        AppAvatarSize.md => 16,
        AppAvatarSize.lg => 20,
        AppAvatarSize.xl => 28,
      };
}

/// Circular avatar that renders a network/asset image, falling back to
/// initials on error or when no image is provided.
///
/// ```dart
/// AppAvatar(imageUrl: user.avatarUrl, name: user.name)
/// AppAvatar.asset('assets/images/discovery/avatars/avatar_1.png', size: AppAvatarSize.sm)
/// ```
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.name,
    this.size = AppAvatarSize.md,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
    this.onTap,
  });

  const AppAvatar.asset(
    String path, {
    Key? key,
    AppAvatarSize size = AppAvatarSize.md,
    Color? borderColor,
    double borderWidth = 0,
    VoidCallback? onTap,
  }) : this(
          key: key,
          assetPath: path,
          size: size,
          borderColor: borderColor,
          borderWidth: borderWidth,
          onTap: onTap,
        );

  final String? imageUrl;
  final String? assetPath;
  final String? name;
  final AppAvatarSize size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final d = size.diameter;
    final hasBorder = borderWidth > 0 && borderColor != null;

    Widget avatar = CircleAvatar(
      radius: d / 2,
      backgroundColor: backgroundColor ?? AppColors.primaryLight,
      child: _buildContent(d),
    );

    if (hasBorder) {
      avatar = Container(
        width: d + borderWidth * 2,
        height: d + borderWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor!,
            width: borderWidth,
          ),
        ),
        child: ClipOval(child: avatar),
      );
    }

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildContent(double d) {
    // Asset image
    if (assetPath != null) {
      return ClipOval(
        child: Image.asset(
          assetPath!,
          width: d,
          height: d,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(d),
        ),
      );
    }

    // Network image
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: d,
          height: d,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(d),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _shimmer(d),
        ),
      );
    }

    return _fallback(d);
  }

  Widget _fallback(double d) => Text(
        _initials,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: size.fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDarker,
        ),
      );

  Widget _shimmer(double d) => Container(
        width: d,
        height: d,
        color: AppColors.surfaceSubtle,
      );
}

/// Overlapping avatar stack — shows the first [maxVisible] avatars
/// and a "+N" overflow pill.
///
/// ```dart
/// AppAvatarStack(
///   avatars: ['assets/...', 'assets/...'],
///   count: 12,
///   size: AppAvatarSize.sm,
/// )
/// ```
class AppAvatarStack extends StatelessWidget {
  const AppAvatarStack({
    super.key,
    required this.avatars,
    this.count,
    this.size = AppAvatarSize.sm,
    this.maxVisible = 3,
    this.overlap = 10.0,
  });

  /// Asset paths or network URLs.
  final List<String> avatars;

  /// Total participant count (used to compute overflow label).
  final int? count;

  final AppAvatarSize size;
  final int maxVisible;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final d = size.diameter;
    final visible = avatars.take(maxVisible).toList();
    final overflow = (count ?? avatars.length) - visible.length;
    final totalWidth =
        d + (visible.length - 1) * (d - overlap) + (overflow > 0 ? d : 0);

    return SizedBox(
      width: totalWidth,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (d - overlap),
              child: AppAvatar(
                assetPath: visible[i].startsWith('assets/') ? visible[i] : null,
                imageUrl: visible[i].startsWith('assets/') ? null : visible[i],
                size: size,
                borderColor: AppColors.surface,
                borderWidth: 2,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (d - overlap),
              child: CircleAvatar(
                radius: d / 2,
                backgroundColor: AppColors.surfaceSubtle,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: size.fontSize - 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
