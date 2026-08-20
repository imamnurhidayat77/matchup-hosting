import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Icon + title/subtitle row used in activity detail screens (date, location,
/// etc). Matches Figma: 36×36 primaryLight pill behind a centered 18×18 SVG,
/// title in 14 bold primary, sub in 12 secondary.
class DetailRowItem extends StatelessWidget {
  const DetailRowItem({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    this.iconBackground,
  });

  final String icon;
  final String title;
  final String sub;
  final Color? iconBackground;

  static const _defaultIconBg = Color(0xFFE6F0FF);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBackground ?? _defaultIconBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 18,
              height: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                sub,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}