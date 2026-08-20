import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/home_indicator.dart';

/// Check-In Screen (spec 5.12)
///
/// Allows location-based attendance check-in for a joined activity.
/// Shows the activity title, location, current check-in status, and a
/// location-permission prompt if needed.
class CheckInScreen extends StatefulWidget {
  final String activityId;

  const CheckInScreen({super.key, required this.activityId});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

enum _CheckInStatus { notCheckedIn, locating, checkedIn, locationDenied }

class _CheckInScreenState extends State<CheckInScreen> {
  _CheckInStatus _status = _CheckInStatus.notCheckedIn;

  // Mock activity metadata. In a real app this would be loaded via the
  // activityId passed into the route.
  static const _activityTitle = 'Saturday Afternoon 5v5 Basketball';
  static const _activityLocation = 'Central Park Court B';
  static const _activitySchedule = 'Sat, Aug 8 • 4:00 PM - 6:00 PM';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hero(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _activityInfo(),
                          const SizedBox(height: 20),
                          _statusCard(),
                          const SizedBox(height: 16),
                          if (_status == _CheckInStatus.locationDenied)
                            _permissionPrompt(),
                          if (_status == _CheckInStatus.locationDenied)
                            const SizedBox(height: 16),
                          _primaryAction(context),
                          const SizedBox(height: 12),
                          if (_status != _CheckInStatus.checkedIn)
                            _secondaryAction(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _circleBtn(
            'assets/images/discovery/icons/arrow_left.svg',
            Icons.arrow_back,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Check-In',
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(String asset, IconData fallback, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: SvgPicture.asset(
            asset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetImageWithFallback(
            assetPath: 'assets/images/discovery/covers/basketball_full.png',
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            semanticLabel: 'Activity cover',
          ),
          Container(color: const Color.fromRGBO(0, 0, 0, 0.15)),
          Positioned(
            left: 20,
            bottom: 16,
            right: 20,
            child: Text(
              _activityTitle,
              style: AppTypography.headlineSmall.copyWith(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            'assets/images/discovery/icons/calendar.svg',
            'Schedule',
            _activitySchedule,
          ),
          const SizedBox(height: 14),
          _infoRow(
            'assets/images/discovery/icons/map_pin.svg',
            'Location',
            _activityLocation,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            icon,
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(AppColors.primaryDarker, BlendMode.srcIn),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    switch (_status) {
      case _CheckInStatus.notCheckedIn:
        return _statusBadge(
          bg: AppColors.warningBg,
          fg: AppColors.warning,
          icon: Icons.access_time_rounded,
          label: 'Not checked in yet',
          description: 'Arrive at the location and tap "Check In" to confirm '
              'your attendance.',
        );
      case _CheckInStatus.locating:
        return _statusBadge(
          bg: AppColors.primaryLight,
          fg: AppColors.primaryDarker,
          icon: Icons.my_location_rounded,
          label: 'Detecting your location…',
          description: 'We are verifying that you are at the activity venue.',
        );
      case _CheckInStatus.checkedIn:
        return _statusBadge(
          bg: AppColors.statusSuccessBg,
          fg: AppColors.avatarSecondary,
          icon: Icons.check_circle_rounded,
          label: 'Checked in',
          description: 'Your attendance has been confirmed. Enjoy the game!',
        );
      case _CheckInStatus.locationDenied:
        return _statusBadge(
          bg: AppColors.warningBg,
          fg: AppColors.warning,
          icon: Icons.location_off_rounded,
          label: 'Location permission needed',
          description: 'Enable location access so we can verify your attendance.',
        );
    }
  }

  Widget _statusBadge({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: fg,
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

  Widget _permissionPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primaryDarker, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'MatchUp uses your location only to confirm you are at the venue. '
              'You can revoke this at any time in your device settings.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction(BuildContext context) {
    final bool isCheckingIn =
        _status == _CheckInStatus.locating;
    final bool isDone = _status == _CheckInStatus.checkedIn;

    final label = isDone
        ? 'Checked In'
        : (isCheckingIn ? 'Locating…' : 'Check In');
    final bg = isDone ? AppColors.avatarSecondary : AppColors.primaryDarker;

    return GestureDetector(
      onTap: isCheckingIn || isDone ? null : _onCheckIn,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCheckingIn)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                isDone ? Icons.check_rounded : Icons.location_on_rounded,
                color: Colors.white,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryAction(BuildContext context) {
    final showRetry = _status == _CheckInStatus.locationDenied ||
        _status == _CheckInStatus.notCheckedIn;

    if (!showRetry) {
      return const SizedBox.shrink();
    }

    return Center(
      child: GestureDetector(
        onTap: _onRetry,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _status == _CheckInStatus.locationDenied
                ? 'Retry location detection'
                : 'Refresh my location',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primaryDarker,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
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
