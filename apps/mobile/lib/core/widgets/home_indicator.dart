import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/dark_colors.dart';

/// iOS home indicator pill (139×5px, 100px radius) shown at the bottom of
/// every screen to match Figma designs.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({
    super.key,
    this.color,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });

  /// Defaults to `context.colors.iconPrimary` (theme-aware) when null. Pass
  /// an explicit colour for indicators drawn on top of a fixed-colour
  /// surface (e.g. the primary-blue splash/onboarding screens), where the
  /// indicator must stay a fixed light colour regardless of the app theme.
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: 139,
          height: 5,
          decoration: BoxDecoration(
            color: color ?? context.colors.iconPrimary,
            borderRadius: AppRadius.pillR,
          ),
        ),
      ),
    );
  }
}
