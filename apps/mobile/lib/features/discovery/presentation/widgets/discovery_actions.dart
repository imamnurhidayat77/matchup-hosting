import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../../../core/widgets/app_tappable.dart';
import '../../../../core/widgets/empty_state.dart';

/// Empty state shown once the swipe deck runs out of activities.
class DiscoveryEmptyDeck extends StatelessWidget {
  const DiscoveryEmptyDeck({super.key, required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.travel_explore_rounded,
      title: "You're all caught up",
      subtitle:
          "You've seen all activities near you. Check back later or "
          'adjust your preferences to see more.',
      actionLabel: 'Start over',
      onAction: onRestart,
    );
  }
}

/// Tinder-style floating action below the swipe deck: a circular button with
/// a caption beneath it. Three presets — [DiscoveryAction.reject] (white
/// circle, red X, "Not now"), [DiscoveryAction.info] (white circle, blue
/// info, "Details") and [DiscoveryAction.join] (gradient circle, basketball,
/// "Join game"). The join button is deliberately larger and glows so the
/// positive action carries more visual weight.
class DiscoveryAction extends StatelessWidget {
  const DiscoveryAction._({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
    required this.filled,
    this.iconColor,
  });

  factory DiscoveryAction.reject({required VoidCallback onTap}) =>
      DiscoveryAction._(
        icon: Icons.close_rounded,
        label: 'Not now',
        onTap: onTap,
        size: 62,
        filled: false,
      );

  factory DiscoveryAction.info({required VoidCallback onTap}) =>
      DiscoveryAction._(
        icon: Icons.info_outline_rounded,
        label: 'Details',
        onTap: onTap,
        size: 54,
        filled: false,
        iconColor: AppColors.primary,
      );

  factory DiscoveryAction.join({required VoidCallback onTap}) =>
      DiscoveryAction._(
        icon: Icons.sports_basketball_rounded,
        label: 'Join game',
        onTap: onTap,
        size: 68,
        filled: true,
      );

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppTappable(
      semanticLabel: label,
      feedback: AppTapFeedback.scale,
      minSize: size,
      borderRadius: size / 2,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? null : c.surface,
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          border: filled ? null : Border.all(color: c.border),
          boxShadow: filled ? AppShadows.glowPrimary : AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: filled ? 30 : (size >= 62 ? 26 : 22),
          color: iconColor ??
              (filled ? AppColors.textOnPrimary : AppColors.danger),
        ),
      ),
    );
  }
}
