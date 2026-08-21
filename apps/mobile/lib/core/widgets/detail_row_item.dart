import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBackground ?? context.colors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
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
                style: AppTypography.bodyMedium(context).copyWith(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                sub,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: context.colors.textSecondary, fontSize: 12),
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
