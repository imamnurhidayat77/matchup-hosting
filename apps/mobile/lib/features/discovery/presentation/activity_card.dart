import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/activity_model.dart';

/// Figma-matching activity card for the discovery swipe deck.
///
/// Layout (390px wide, card body ~358px after 16px page padding):
///   cover 240h | title 22 ExtraBold | chip row | description | divider | footer
class ActivityCard extends StatelessWidget {
  final String title;
  final String sportType;
  final String location;
  final double distanceKm;
  final DateTime dateTime;
  final String skillLevel;
  final int capacity;
  final int participantCount;
  final String hostName;
  final String? coverImageUrl;
  final ActivityStatus status;
  final String? description;

  const ActivityCard({
    super.key,
    required this.title,
    required this.sportType,
    required this.location,
    required this.distanceKm,
    required this.dateTime,
    required this.skillLevel,
    required this.capacity,
    required this.participantCount,
    required this.hostName,
    this.coverImageUrl,
    this.status = ActivityStatus.available,
    this.description,
  });

  String get _statusText {
    switch (status) {
      case ActivityStatus.available:
        return 'Open';
      case ActivityStatus.almostFull:
        return 'Almost full';
      case ActivityStatus.full:
        return 'Full';
      case ActivityStatus.joined:
        return 'Joined';
      case ActivityStatus.hosted:
        return 'Hosting';
      case ActivityStatus.past:
        return 'Past';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = capacity == 0
        ? 0.0
        : (participantCount / capacity).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverImageUrl != null)
                  Image.asset(coverImageUrl!, fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                    ),
                  ),
                // Gradient scrim — darkens bottom edge so sport/distance badges
                // remain legible on any photo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1.0],
                        colors: [Colors.transparent, AppColors.scrim],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.mdR,
                    ),
                    child: Text(
                      sportType,
                      style: AppTypography.badgeSport.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: AppColors.scrim,
                      borderRadius: AppRadius.lgR,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/discovery/icons/map_pin.svg',
                          width: 12,
                          height: 12,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textOnPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km away',
                          style: AppTypography.chipLabel.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleScreen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.x4),
                Row(
                  children: [
                    _Chip(
                      iconAsset: 'assets/images/discovery/icons/zap.svg',
                      label: skillLevel.toUpperCase(),
                      textColor: AppColors.primaryDarker,
                      background: AppColors.background,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      iconAsset: 'assets/images/discovery/icons/clock.svg',
                      label: _formatDateTime(dateTime),
                      textColor: AppColors.textPrimary,
                      background: AppColors.background,
                    ),
                  ],
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    description!,
                    style: AppTypography.bodyReading.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.x4),
                Row(
                  children: [
                    _AvatarStack(),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$participantCount / $capacity spots',
                            style: AppTypography.countAccent.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x1 + 2),
                          ClipRRect(
                            borderRadius: AppRadius.xsR,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: AppSpacing.x2 - 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccessBg,
                        borderRadius: AppRadius.lgR,
                      ),
                      child: Text(
                        _statusText,
                        style: AppTypography.badgeSport.copyWith(
                          color: AppColors.statusSuccessText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (eventDate == today) return 'Today, $time';
    if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, $time';
    }
    final months = [
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
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.iconAsset,
    required this.label,
    required this.textColor,
    required this.background,
  });

  final String iconAsset;
  final String label;
  final Color textColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.lgR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 13,
            height: 13,
            colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.chipLabel.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final initials = const ['M', 'J'];
    final colors = const [AppColors.primary, AppColors.avatarSecondary];
    return SizedBox(
      width: 82,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == 0 ? AppColors.avatarNeutral : colors[i - 1],
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                alignment: Alignment.center,
                child: i == 0
                    ? null
                    : Text(
                        initials[i - 1],
                        style: AppTypography.badgeSport.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
