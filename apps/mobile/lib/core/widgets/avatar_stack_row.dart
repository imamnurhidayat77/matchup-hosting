import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';
import 'asset_image.dart';

/// Horizontal stack of overlapping circular avatars ending with an optional
/// "+N" tile. Used in activity detail and participants headers.
class AvatarStackRow extends StatelessWidget {
  const AvatarStackRow({
    super.key,
    required this.avatars,
    this.moreLabel,
    this.size = 32,
    this.overlap = 10,
  });

  final List<String> avatars;
  final String? moreLabel;
  final double size;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Row(
        children: [
          for (var i = 0; i < avatars.length; i++)
            _avatar(context, avatars[i], i == 0 ? 0 : overlap),
          if (moreLabel != null) _more(context, moreLabel!, overlap),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String asset, double right) {
    return Padding(
      padding: EdgeInsets.only(right: right),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.surface, width: 2),
        ),
        child: ClipOval(
          child: AssetImageWithFallback(
            assetPath: 'assets/images/discovery/avatars/$asset',
            width: size,
            height: size,
            fit: BoxFit.cover,
            isAvatar: true,
          ),
        ),
      ),
    );
  }

  Widget _more(BuildContext context, String label, double right) {
    return Padding(
      padding: EdgeInsets.only(right: right),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.border,
          border: Border.all(color: context.colors.surface, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
