import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../../../core/widgets/app_tappable.dart';
import '../../../../core/widgets/empty_state.dart';

/// Empty state shown once the swipe deck runs out of activities.
///
/// When [filterSummary] is non-empty the deck is empty *because of* the
/// active filter (e.g. "Basketball · Within 5 km" from 7,000 km away) —
/// so the copy says so and a "Clear filters" escape hatch appears next
/// to "Start over" instead of leaving the user guessing.
class DiscoveryEmptyDeck extends StatelessWidget {
  const DiscoveryEmptyDeck({
    super.key,
    required this.onRestart,
    this.filterSummary,
    this.onClearFilters,
  });

  final VoidCallback onRestart;

  /// Human-readable active filter, e.g. "Basketball · Within 5 km".
  /// Null/empty means no filter is active.
  final String? filterSummary;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final filtered = (filterSummary ?? '').isNotEmpty;
    // Max + centered: the parent Padding fills the Expanded deck area,
    // so this puts the content back in the vertical middle (where the
    // old bare-EmptyState layout had it via its own Center).
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmptyState(
          icon: Icons.travel_explore_rounded,
          title: filtered ? 'No matches for these filters' : "You're all caught up",
          subtitle: filtered
              ? 'Nothing within $filterSummary. Loosen the filters or check back later.'
              : "You've seen all activities near you. Check back later or "
                  'adjust your preferences to see more.',
          actionLabel: 'Start over',
          onAction: onRestart,
        ),
        if (filtered && onClearFilters != null) ...[
          const SizedBox(height: AppSpacing.x3),
          AppTappable(
            semanticLabel: 'Clear filters',
            onTap: onClearFilters!,
            feedback: AppTapFeedback.scale,
            minSize: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Text(
                'Clear filters',
                style: AppTypography.labelField(context).copyWith(
                  color: context.colors.primaryOnSurface,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Which theme-aware foreground colour an unfilled [DiscoveryAction] uses —
/// factory constructors run before a [BuildContext] exists, so the actual
/// [Color] is resolved in [DiscoveryAction.build] instead of being baked in
/// at construction time (that's what let the "Details" button's icon
/// silently hardcode `AppColors.primary`, invisible on a dark card).
enum _ActionTone { reject, info }

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
    // `this._tone` would force the callsite parameter name to also be
    // `_tone` (private), which the named-arg-at-callsite check then
    // rejects — the public `tone` name is required for
    // `DiscoveryAction.info(tone: ...)` below to compile.
    _ActionTone tone = _ActionTone.reject,
  }) : _tone = tone; // ignore: prefer_initializing_formals

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
        tone: _ActionTone.info,
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
  final _ActionTone _tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = filled
        ? AppColors.textOnPrimary
        : switch (_tone) {
            _ActionTone.info => c.primaryOnSurface,
            _ActionTone.reject => c.errorText,
          };
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
          color: iconColor,
        ),
      ),
    );
  }
}
