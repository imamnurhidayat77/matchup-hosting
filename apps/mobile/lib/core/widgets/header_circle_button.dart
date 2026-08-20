import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Circular icon button used in screen headers (back, more, share). Matches
/// Figma header pattern: 36×36 surface pill with an SVG centered at 20×20.
/// Wrap in `Semantics` at the call site to set the a11y label.
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    this.assetPath,
    this.fallbackIcon,
    this.onTap,
    this.background,
  }) : assert(
         assetPath != null || fallbackIcon != null,
         'Provide assetPath or fallbackIcon',
       );

  final String? assetPath;
  final IconData? fallbackIcon;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background ?? AppColors.surface,
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: assetPath != null
            ? SizedBox(
                width: 20,
                height: 20,
                child: SvgPicture.asset(assetPath!, width: 20, height: 20),
              )
            : Icon(fallbackIcon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
