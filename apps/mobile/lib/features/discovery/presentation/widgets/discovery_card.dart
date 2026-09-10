import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/asset_image.dart';
import '../../domain/activity_model.dart';

/// Discovery swipe-deck card — a Tinder-style card that does NOT fill the
/// screen: a large hero photo (with sport + distance pills) sitting above a
/// clean info block (title, skill/time/location chips, description, and a
/// social footer with participant avatars, a spots progress bar, and a status
/// chip).
///
/// The card owns layout only; it takes its data straight from
/// [ActivityModel]. The action buttons live OUTSIDE the card (in the
/// discovery screen) so this widget is purely the swipeable surface.
class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({super.key, required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.xlR,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Tinder-style fill layout: the hero image is the flex element that
      // absorbs whatever vertical space is left after the info block takes
      // its natural height. The card fills the deck area exactly (no bottom
      // overflow) while the info block is never clipped mid-row.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _HeroImage(activity: activity)),
          _CardInfo(activity: activity),
        ],
      ),
    );
  }
}

// ─── Hero image + overlays ────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    // Fills the flex space handed down by the card's Expanded, with a tall
    // floor so the hero photo stays prominent (cinematic).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 236),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (activity.coverImageUrl != null)
            AssetImageWithFallback(
              imagePath: activity.coverImageUrl!,
              fit: BoxFit.cover,
            )
          else
            const _CoverPlaceholder(),

          // Top-edge scrim so the pills stay legible on any photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.32],
                  colors: [AppColors.scrim, AppColors.scrimTransparent],
                ),
              ),
            ),
          ),

          // Sport badge — blue pill, top-left.
          Positioned(
            top: AppSpacing.x3,
            left: AppSpacing.x3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.pillR,
                boxShadow: AppShadows.glowPrimary,
              ),
              child: Text(
                activity.sportType.toUpperCase(),
                style: AppTypography.badgeSport(
                  context,
                ).copyWith(
                  color: AppColors.textOnPrimary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // Distance pill — dark translucent, top-right. Hidden when
          // the distance is unknown (0 means "no GPS fix", not
          // "at the venue") so we never show a misleading 0.0 km.
          if (activity.distanceKm > 0)
            Positioned(
              top: AppSpacing.x3,
              right: AppSpacing.x3,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A),
                  borderRadius: AppRadius.pillR,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppIcons.mapPin,
                      size: AppIconSize.sm,
                      color: AppColors.textOnPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${activity.distanceKm.toStringAsFixed(1)} km away',
                      style: AppTypography.chipLabel(
                        context,
                      ).copyWith(color: AppColors.textOnPrimary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Info block ─────────────────────────────────────────────────────────────

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x4,
        AppSpacing.x5,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title.
          Text(
            activity.title,
            style: AppTypography.headlineMedium(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.x3),

          // Skill · time · location chips.
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              _InfoChip(
                icon: AppIcons.zap,
                label: activity.skillLevel.toUpperCase(),
                iconColor: c.primaryOnSurface,
              ),
              _InfoChip(
                icon: AppIcons.clock,
                label: _formatDateTime(activity.dateTime),
                iconColor: c.textSecondary,
              ),
              _InfoChip(
                icon: AppIcons.mapPin,
                label: activity.location,
                iconColor: c.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3 + 2),

          // Description.
          if (activity.description.isNotEmpty) ...[
            Text(
              activity.description,
              style: AppTypography.bodyReading(
                context,
              ).copyWith(color: c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.x3 + 2),
          ],

          Divider(height: 1, color: c.border),
          const SizedBox(height: AppSpacing.x3 + 2),

          // Social footer: avatars + spots progress + status.
          Row(
            children: [
              _ParticipantAvatars(count: activity.participantCount),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activity.participantCount} / ${activity.capacity} spots',
                      style: AppTypography.labelField(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _SpotsProgressBar(
                      value: activity.capacity > 0
                          ? activity.participantCount / activity.capacity
                          : 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              _StatusChip(status: activity.status),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small pieces ─────────────────────────────────────────────────────────

/// Rounded pill with an icon + label — the skill / time / location chips.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final String icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.pillR,
        border: Border.all(color: c.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppIconSize.sm, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.chipLabel(context).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar for the "x / y spots" fill.
class _SpotsProgressBar extends StatelessWidget {
  const _SpotsProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: AppRadius.pillR,
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.surfaceMuted)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Availability pill — "Open" / "Almost full" / "Full" etc.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, String label) = switch (status) {
      ActivityStatus.available => (
        c.successBg,
        c.successText,
        'Open',
      ),
      ActivityStatus.almostFull => (c.warningBg, c.warningText, 'Few left'),
      ActivityStatus.full => (c.errorLight, c.errorText, 'Full'),
      ActivityStatus.joined => (c.primarySoft, c.primaryOnSurface, 'Joined'),
      ActivityStatus.hosted => (c.primarySoft, c.primaryOnSurface, 'Hosting'),
      ActivityStatus.past => (c.surfaceMuted, c.textSecondary, 'Past'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillR),
      child: Text(
        label,
        style: AppTypography.chipLabel(
          context,
        ).copyWith(fontSize: 13, color: fg),
      ),
    );
  }
}

class _ParticipantAvatars extends StatelessWidget {
  const _ParticipantAvatars({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = count.clamp(0, 3);
    const size = 34.0;
    const step = 22.0;
    if (visible == 0) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      width: step * (visible - 1) + size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.primaryLight,
                  border: Border.all(color: c.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_rounded,
                  size: 17,
                  color: c.primaryOnSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.sports_basketball_rounded,
        size: 64,
        color: AppColors.textOnPrimary.withValues(alpha: 0.4),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDate = DateTime(dt.year, dt.month, dt.day);
  final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  final time = '$hour12:$minute $period';
  if (eventDate == today) return 'Today, $time';
  if (eventDate == today.add(const Duration(days: 1))) return 'Tomorrow, $time';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, $time';
}
