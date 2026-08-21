import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';

final _checkInActivityProvider = FutureProvider.autoDispose
    .family<ActivityModel, String>((ref, activityId) async {
      final activity = await ref
          .watch(activityRepositoryProvider)
          .byId(activityId);
      if (activity == null) throw StateError('Activity not found');
      return activity;
    });

/// Check-In Screen (spec 5.12)
///
/// Allows location-based attendance check-in for a joined activity.
/// Shows the activity title, location, current check-in status, and a
/// location-permission prompt if needed.
class CheckInScreen extends ConsumerStatefulWidget {
  final String activityId;

  const CheckInScreen({super.key, required this.activityId});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

enum _CheckInStatus { notCheckedIn, locating, checkedIn, locationDenied }

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  _CheckInStatus _status = _CheckInStatus.notCheckedIn;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_checkInActivityProvider(widget.activityId));

    return AppScaffold.detail(
      title: 'Check-In',
      showHomeIndicator: false, // reached from inside ShellRoute screens.
      backgroundColor: context.colors.surface,
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () =>
              ref.invalidate(_checkInActivityProvider(widget.activityId)),
        ),
        data: (activity) => _CheckInBody(
          activity: activity,
          status: _status,
          onCheckIn: _onCheckIn,
          onRetry: _onRetry,
        ),
      ),
    );
  }

  Future<void> _onCheckIn() async {
    // Mock location detection flow. A real implementation would request
    // location permissions, fetch the device position, and compare it to the
    // venue coordinates.
    setState(() => _status = _CheckInStatus.locating);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // For the demo we assume the user is on-site.
    setState(() => _status = _CheckInStatus.checkedIn);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in successful! You are at the venue.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onRetry() async {
    setState(() => _status = _CheckInStatus.locating);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // On retry we simulate a successful detection.
    setState(() => _status = _CheckInStatus.checkedIn);
  }
}

class _CheckInBody extends StatelessWidget {
  const _CheckInBody({
    required this.activity,
    required this.status,
    required this.onCheckIn,
    required this.onRetry,
  });

  final ActivityModel activity;
  final _CheckInStatus status;
  final Future<void> Function() onCheckIn;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(activity: activity),
          const SizedBox(height: AppSpacing.x5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivityInfo(activity: activity),
                const SizedBox(height: AppSpacing.x5),
                _StatusCard(status: status),
                const SizedBox(height: AppSpacing.x4),
                if (status == _CheckInStatus.locationDenied) ...[
                  const _PermissionPrompt(),
                  const SizedBox(height: AppSpacing.x4),
                ],
                _PrimaryAction(status: status, onCheckIn: onCheckIn),
                const SizedBox(height: AppSpacing.x3),
                if (status != _CheckInStatus.checkedIn)
                  _SecondaryAction(status: status, onRetry: onRetry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetImageWithFallback(
            assetPath:
                activity.coverImageUrl ??
                'assets/images/discovery/covers/basketball_full.png',
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            semanticLabel: 'Activity cover',
          ),
          Container(color: context.colors.shadow),
          Positioned(
            left: AppSpacing.x5,
            bottom: AppSpacing.x4,
            right: AppSpacing.x5,
            child: Text(
              activity.title,
              style: AppTypography.headlineSmall(
                context,
              ).copyWith(color: context.colors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityInfo extends StatelessWidget {
  const _ActivityInfo({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final scheduleFmt = DateFormat('EEE, MMM d • h:mm a');
    final timeRangeFmt = DateFormat('h:mm a');
    final schedule =
        '${scheduleFmt.format(activity.dateTime)} - '
        '${timeRangeFmt.format(activity.endTime)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: 'assets/images/discovery/icons/calendar.svg',
            label: 'Schedule',
            value: schedule,
          ),
          const SizedBox(height: AppSpacing.x3 + 2),
          _InfoRow(
            icon: 'assets/images/discovery/icons/map_pin.svg',
            label: 'Location',
            value: activity.location,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.colors.primaryLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            icon,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              context.colors.primaryOnSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.labelField(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final _CheckInStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _CheckInStatus.notCheckedIn:
        return _StatusBadge(
          bg: context.colors.warningBg,
          fg: AppColors.warning,
          icon: Icons.access_time_rounded,
          label: 'Not checked in yet',
          description:
              'Arrive at the location and tap "Check In" to confirm '
              'your attendance.',
        );
      case _CheckInStatus.locating:
        return _StatusBadge(
          bg: context.colors.primaryLight,
          fg: context.colors.primaryOnSurface,
          icon: Icons.my_location_rounded,
          label: 'Detecting your location…',
          description: 'We are verifying that you are at the activity venue.',
        );
      case _CheckInStatus.checkedIn:
        return _StatusBadge(
          bg: context.colors.statusSuccessBg,
          fg: AppColors.avatarSecondary,
          icon: Icons.check_circle_rounded,
          label: 'Checked in',
          description: 'Your attendance has been confirmed. Enjoy the game!',
        );
      case _CheckInStatus.locationDenied:
        return _StatusBadge(
          bg: context.colors.warningBg,
          fg: AppColors.warning,
          icon: Icons.location_off_rounded,
          label: 'Location permission needed',
          description:
              'Enable location access so we can verify your attendance.',
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
    required this.description,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelField(
                    context,
                  ).copyWith(color: fg, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  description,
                  style: AppTypography.bodyReading(
                    context,
                  ).copyWith(color: fg, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: context.colors.primaryOnSurface,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.x2 + 2),
          Expanded(
            child: Text(
              'MatchUp uses your location only to confirm you are at the venue. '
              'You can revoke this at any time in your device settings.',
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.status, required this.onCheckIn});
  final _CheckInStatus status;
  final Future<void> Function() onCheckIn;

  @override
  Widget build(BuildContext context) {
    final bool isCheckingIn = status == _CheckInStatus.locating;
    final bool isDone = status == _CheckInStatus.checkedIn;

    final label = isDone
        ? 'Checked In'
        : (isCheckingIn ? 'Locating…' : 'Check In');
    final bg = isDone
        ? AppColors.avatarSecondary
        : context.colors.primaryOnSurface;

    return PressableScale(
      onTap: isCheckingIn || isDone ? null : onCheckIn,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCheckingIn)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.textOnPrimary,
                ),
              )
            else
              Icon(
                isDone ? Icons.check_rounded : Icons.location_on_rounded,
                color: context.colors.textOnPrimary,
                size: 18,
              ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              label,
              style: AppTypography.labelField(
                context,
              ).copyWith(color: context.colors.textOnPrimary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.status, required this.onRetry});
  final _CheckInStatus status;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final showRetry =
        status == _CheckInStatus.locationDenied ||
        status == _CheckInStatus.notCheckedIn;

    if (!showRetry) {
      return const SizedBox.shrink();
    }

    return Center(
      child: PressableScale(
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Text(
            status == _CheckInStatus.locationDenied
                ? 'Retry location detection'
                : 'Refresh my location',
            style: AppTypography.chipLabel(
              context,
            ).copyWith(color: context.colors.primaryOnSurface),
          ),
        ),
      ),
    );
  }
}
