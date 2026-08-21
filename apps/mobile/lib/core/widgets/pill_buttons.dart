import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgPicture;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';

/// Primary pill button matching Figma (`border-radius: 100px`, 16px vertical
/// padding, 24px horizontal padding, white bold text on `primary`).
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = AppColors.primary,
    this.foreground = AppColors.textOnPrimary,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon; // path to an SVG asset
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: disabled ? background.withValues(alpha: 0.6) : background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.buttonPrimary.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: SvgPicture.asset(
                        icon!,
                        colorFilter: ColorFilter.mode(
                          foreground,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined pill button matching Figma (white card background, 1px border, 14px
/// vertical padding). For social sign-in (Apple, Google) and secondary actions.
class SocialPillButton extends StatelessWidget {
  const SocialPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon; // path to SVG or PNG asset
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: Material(
          color: context.colors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: context.colors.border.withValues(alpha: 0.9),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    SizedBox(width: 20, height: 20, child: _icon(icon!)),
                    const SizedBox(width: 12),
                  ],
                  Text(label, style: AppTypography.buttonSocial(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(String path) {
    final isSvg = path.toLowerCase().endsWith('.svg');
    if (isSvg) {
      return SvgPicture.asset(path, fit: BoxFit.contain);
    }
    return Image.asset(path, fit: BoxFit.contain);
  }
}

/// Solid pill button for primary CTAs that overlay dark scrims (e.g. onboarding
/// buttons). Same shape as [PrimaryPillButton] but takes any background color.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.background = AppColors.primary,
    this.foreground = AppColors.textOnPrimary,
    this.icon,
    this.expand = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final String? icon;
  final bool expand;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: Material(
          color: onPressed == null
              ? background.withValues(alpha: 0.6)
              : background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.buttonPrimary.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: SvgPicture.asset(
                        icon!,
                        colorFilter: ColorFilter.mode(
                          foreground,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
