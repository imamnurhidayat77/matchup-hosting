import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard card surface for MatchUp.
///
/// Usage:
/// ```dart
/// AppCard(
///   onTap: () {},
///   child: ...,
/// )
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.x4),
    this.radius = AppRadius.lg,
    this.color = AppColors.surface,
    this.border = true,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: AppColors.border) : null,
            boxShadow: shadow ? AppShadows.card : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
