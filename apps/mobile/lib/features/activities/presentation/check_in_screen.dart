import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _checkInActivityProvider = FutureProvider.autoDispose
    .family<ActivityModel, String>((ref, activityId) async {
  final activity =
      await ref.watch(activityRepositoryProvider).byId(activityId);
  if (activity == null) throw StateError('Activity not found');
  return activity;
});

// ─── Status enum ─────────────────────────────────────────────────────────────

enum _CheckInStatus { notCheckedIn, locating, checkedIn, locationDenied }

// ─── Screen ──────────────────────────────────────────────────────────────────

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, required this.activityId});
  final String activityId;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  _CheckInStatus _status = _CheckInStatus.notCheckedIn;

  Future<void> _onCheckIn() async {
    setState(() => _status = _CheckInStatus.locating);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _status = _CheckInStatus.checkedIn);
  }

  Future<void> _onRefresh() async {
    setState(() => _status = _CheckInStatus.locating);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _status = _CheckInStatus.checkedIn);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_checkInActivityProvider(widget.activityId));

    return AppScaffold(
      safeAreaTop: false,
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () =>
              ref.invalidate(_checkInActivityProvider(widget.activityId)),
        ),
        data: (activity) => _Body(
          activity: activity,
          status: _status,
          onCheckIn: _onCheckIn,
          onRefresh: _onRefresh,
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.activity,
    required this.status,
    required this.onCheckIn,
    required this.onRefresh,
  });

  final ActivityModel activity;
  final _CheckInStatus status;
  final Future<void> Function() onCheckIn;
  final Future<void> Function() onRefresh;

  static const double _heroHeight = 280;
  static const double _overlapAmount = 44;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // ── Hero ──────────────────────────────────────────────────
              SizedBox(
                height: _heroHeight,
                width: double.infinity,
                child: _Hero(activity: activity),
              ),

              // ── White card ────────────────────────────────────────────
              Positioned(
                top: _heroHeight - _overlapAmount,
                left: 0,
                right: 0,
                bottom: 0,
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                      boxShadow: AppShadows.sheet,
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x5,
                      AppSpacing.x5,
                      AppSpacing.x5,
                      AppSpacing.x6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          activity.title,
                          style: AppTypography.headingDisplay(context),
                        ),
                        const SizedBox(height: AppSpacing.x2),

                        // Time — blue with clock icon
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: context.colors.primaryOnSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(activity.dateTime),
                              style: AppTypography.labelField(context).copyWith(
                                color: context.colors.primaryOnSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x5),

                        // Activity details section
                        Text(
                          'Activity Details',
                          style: AppTypography.titleMedium(context),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        _DetailsCard(activity: activity),
                        const SizedBox(height: AppSpacing.x4),

                        // Status panel
                        _StatusPanel(status: status),
                        const SizedBox(height: AppSpacing.x4),

                        // Check In button
                        _CheckInButton(
                          status: status,
                          onCheckIn: onCheckIn,
                        ),
                        const SizedBox(height: AppSpacing.x3),

                        // Refresh my location link
                        if (status != _CheckInStatus.checkedIn)
                          Center(
                            child: AppTappable(
                              semanticLabel: 'Refresh my location',
                              feedback: AppTapFeedback.scale,
                              onTap: onRefresh,
                              minSize: 44,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: context.colors.primaryOnSurface,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Refresh my location',
                                    style: AppTypography.labelField(
                                      context,
                                    ).copyWith(
                                      color: context.colors.primaryOnSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final prefix = isToday ? 'Today' : DateFormat('EEE, MMM d').format(dt);
    final time = DateFormat('h:mm a').format(dt);
    return '$prefix, $time';
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image (bundled asset or remote Storage URL)
        activity.coverImageUrl != null
            ? AssetImageWithFallback(
                imagePath: activity.coverImageUrl!,
                fit: BoxFit.cover,
              )
            : _placeholder(),

        // Bottom gradient scrim
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.scrimTransparent, AppColors.scrimGradient],
              stops: [0.4, 1.0],
            ),
          ),
        ),

        // Back + share buttons + centered "Check-In" title
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x5,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                children: [
                  _HeroBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Check-In',
                        style: AppTypography.titleSheet(context).copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                  _HeroBtn(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sport + distance badges — bottom
        Positioned(
          left: AppSpacing.x5,
          bottom: AppSpacing.x4 + 40,
          child: Row(
            children: [
              // Sport — white pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  activity.sportType.toUpperCase(),
                  style: AppTypography.chipLabel(context).copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              // Distance — green pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: AppColors.textOnPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.distanceKm.toStringAsFixed(1)} KM AWAY',
                      style: AppTypography.chipLabel(context).copyWith(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.sports,
        size: 64,
        color: AppColors.textOnPrimary.withValues(alpha: 0.38),
      ),
    ),
  );
}

class _HeroBtn extends StatelessWidget {
  const _HeroBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.scrimControl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 18, color: AppColors.textOnPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Details card ─────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(activity.dateTime);
    final startStr = DateFormat('h:mm a').format(activity.dateTime);
    final endStr = DateFormat('h:mm a').format(activity.endTime);
    final address =
        activity.addressLine ??
        '${activity.distanceKm.toStringAsFixed(1)} km away';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _DetailRow(
            iconBg: context.colors.primarySoft,
            icon: Icons.bolt_rounded,
            iconColor: context.colors.primaryOnSurface,
            title: '${activity.skillLevel.toUpperCase()} LEVEL',
            subtitle: activity.description.isNotEmpty
                ? activity.description.split('.').first
                : 'Join us for a great game',
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _DetailRow(
            iconBg: context.colors.primarySoft,
            icon: Icons.access_time_rounded,
            iconColor: context.colors.primaryOnSurface,
            title: '$dateStr · $startStr – $endStr',
            subtitle: 'Arrive 10m early to warm up',
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _DetailRow(
            iconBg: context.colors.primarySoft,
            icon: Icons.place_outlined,
            iconColor: context.colors.primaryOnSurface,
            title: activity.location,
            subtitle: address,
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _DetailRow(
            iconBg: context.colors.primarySoft,
            icon: Icons.attach_money_rounded,
            iconColor: context.colors.primaryOnSurface,
            title: activity.isPaid ? 'Paid Activity' : 'Free Activity',
            subtitle:
                activity.isPaid ? 'Fee required to join' : 'No cost to join',
            trailingChip: _FeeChip(isPaid: activity.isPaid),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingChip,
  });
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailingChip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelField(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.metaSub(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailingChip != null) ...[
            const SizedBox(width: AppSpacing.x2),
            trailingChip!,
          ],
        ],
      ),
    );
  }
}

class _FeeChip extends StatelessWidget {
  const _FeeChip({required this.isPaid});
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isPaid ? context.colors.warningBg : context.colors.statusSuccessBg;
    final fgColor =
        isPaid ? context.colors.warningText : context.colors.successText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Free',
        style: AppTypography.chipLabel(context).copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Status panel ─────────────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});
  final _CheckInStatus status;

  @override
  Widget build(BuildContext context) {
    /// Accent resolution per (status, theme): all semantic accents come
    /// from theme-aware tokens (successText, warningText, errorText) so
    /// both light and dark mode hit WCAG AA on the corresponding status
    /// background without per-call branching.
    final (Color bg, Color accent, IconData icon, String title, String body) =
        switch (status) {
      _CheckInStatus.notCheckedIn => (
          context.colors.warningBg,
          context.colors.warningText,
          Icons.access_time_rounded,
          'Not checked in yet',
          'Arrive at the location and tap "Check In" below to confirm your attendance.',
        ),
      _CheckInStatus.locating => (
          context.colors.primarySoft,
          context.colors.primaryOnSurface,
          Icons.my_location_rounded,
          'Detecting your location…',
          'We are verifying that you are at the activity venue.',
        ),
      _CheckInStatus.checkedIn => (
          context.colors.statusSuccessBg,
          context.colors.successText,
          Icons.check_circle_rounded,
          'Checked in!',
          'Your attendance has been confirmed. Enjoy the game!',
        ),
      _CheckInStatus.locationDenied => (
          context.colors.warningBg,
          context.colors.warningText,
          Icons.location_off_rounded,
          'Location permission needed',
          'Enable location access so we can verify your attendance.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelField(context).copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.metaSub(context).copyWith(
                    color: accent,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Check In button ──────────────────────────────────────────────────────────

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.status, required this.onCheckIn});
  final _CheckInStatus status;
  final Future<void> Function() onCheckIn;

  @override
  Widget build(BuildContext context) {
    final isLocating = status == _CheckInStatus.locating;
    final isDone = status == _CheckInStatus.checkedIn;

    return PressableScale(
      onTap: (isLocating || isDone) ? null : onCheckIn,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.statusSuccessText
              : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: isDone ? null : AppShadows.glowPrimary,
        ),
        alignment: Alignment.center,
        child: isLocating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.textOnPrimary),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_outline_rounded
                        : Icons.location_on_rounded,
                    size: 20,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    isDone ? 'Checked In' : 'Check In',
                    style: AppTypography.buttonPrimary,
                  ),
                ],
              ),
      ),
    );
  }
}
