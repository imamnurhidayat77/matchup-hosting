import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/avatar_stack_row.dart';
import '../../../core/widgets/detail_row_item.dart';
import '../../../core/widgets/header_circle_button.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/label_badge.dart';

class JoinedActivityDetailScreen extends StatelessWidget {
  final String activityId;
  const JoinedActivityDetailScreen({super.key, required this.activityId});

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Leave Activity?'),
        content: const Text(
          'Are you sure you want to leave this activity? You can re-join later if spots are available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'You have left the activity.',
      variant: AppSnackbarVariant.info,
    );
    // ignore: use_build_context_synchronously
    context.go('/activities');
  }

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
                    _hero(context),
                    const SizedBox(height: 20),
                    // Joined status banner — instantly signals "you are in"
                    // and shifts the page's job from persuading to coordinating.
                    _joinedBanner(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badgesRow(),
                          const SizedBox(height: 12),
                          Text(
                            'Saturday Afternoon 5v5 Basketball',
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _detailItem(
                            icon: 'calendar.svg',
                            title: 'Sat, Aug 8 • 4:00 PM',
                            sub: '4:00 PM - 6:00 PM',
                          ),
                          const SizedBox(height: 14),
                          _detailItem(
                            icon: 'map_pin.svg',
                            title: 'Central Park Court B',
                            sub: 'New York, NY 10024',
                          ),
                          const SizedBox(height: 14),
                          _metaChips(),
                          const SizedBox(height: 14),
                          _participantsRow(),
                          const SizedBox(height: 20),
                          _hostCard(context),
                          const SizedBox(height: 20),
                          _chatSection(context),
                          const SizedBox(height: 16),
                          _addToCalendarButton(context),
                          const SizedBox(height: 8),
                          _checkInButton(context),
                          const SizedBox(height: 8),
                          Center(
                            child: Semantics(
                              button: true,
                              label: 'Leave Activity',
                              child: GestureDetector(
                                onTap: () => _confirmLeave(context),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Leave Activity',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.danger,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
          Semantics(
            button: true,
            label: 'Back',
            child: HeaderCircleButton(
              assetPath: 'assets/images/discovery/icons/arrow_left.svg',
              fallbackIcon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
              background: AppColors.surfaceSubtle,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Activity Details',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'More options',
            child: HeaderCircleButton(
              assetPath: 'assets/images/discovery/icons/more_horizontal.svg',
              fallbackIcon: Icons.more_horiz,
              background: AppColors.surfaceSubtle,
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmation banner shown only on the joined variant.
  Widget _joinedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.avatarSecondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: AppColors.avatarSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re in!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.avatarSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined · See you on Saturday, Oct 24 at 4:00 PM',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.avatarSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetImageWithFallback(
            assetPath: 'assets/images/discovery/covers/basketball_full.png',
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            semanticLabel: 'Activity cover',
          ),
          Container(color: AppColors.shadow),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.avatarSecondary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/check.svg',
                      width: 12,
                      height: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'JOINED',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgesRow() {
    return Row(
      children: [
        LabelBadge(
          label: 'Basketball',
          background: AppColors.primarySoft,
          foreground: AppColors.primaryDarker,
        ),
        const SizedBox(width: 8),
        LabelBadge(
          label: 'CONFIRMED',
          background: AppColors.statusSuccessBg,
          foreground: AppColors.avatarSecondary,
        ),
      ],
    );
  }

  Widget _detailItem({
    required String icon,
    required String title,
    required String sub,
  }) {
    return DetailRowItem(icon: icon, title: title, sub: sub);
  }

  Widget _metaChips() {
    return Row(
      children: [
        _metaChip('zap.svg', 'Intermediate', AppColors.textPrimary),
        const SizedBox(width: 8),
        _metaChip('dollar_sign.svg', 'Free', AppColors.avatarSecondary),
      ],
    );
  }

  Widget _metaChip(String icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 12,
              height: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantsRow() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Participants',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '6 joined / 10 total',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primaryDarker,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AvatarStackRow(
            avatars: const [
              'avatar_1.png',
              'avatar_2.png',
              'avatar_3.png',
              'avatar_4.png',
              'avatar_5.png',
            ],
            moreLabel: '+1',
          ),
        ],
      ),
    );
  }

  Widget _hostCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player-profile/James%20Wilson'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AssetImageWithFallback(
                assetPath: 'assets/images/discovery/avatars/host_james.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                isAvatar: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'James Wilson',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Host',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Message host',
              child: GestureDetector(
                onTap: () => context.push('/chat/James%20Wilson'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/message_circle.svg',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Group Chat',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _chatMsg(
                avatar: 'msg_alex.png',
                sender: 'Alex Mercer',
                time: '10:14 AM',
                text:
                    'Bringing the basketball pump just in case. See you guys at 4!',
              ),
              const SizedBox(height: 12),
              _chatMsg(
                avatar: 'msg_sarah.png',
                sender: 'Sarah Chen',
                time: '10:16 AM',
                text: 'Awesome! I will bring both a white and black jersey.',
              ),
              const SizedBox(height: 12),
              _openChatButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chatMsg({
    required String avatar,
    required String sender,
    required String time,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AssetImageWithFallback(
            assetPath: 'assets/images/discovery/avatars/$avatar',
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            isAvatar: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sender,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    time,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _openChatButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/messages'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: SvgPicture.asset(
                'assets/images/discovery/icons/message_square.svg',
                width: 16,
                height: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Open Group Chat',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primaryDarker,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addToCalendarButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ok = await CalendarService.instance.addEvent(
          title: 'Saturday Afternoon 5v5 Basketball',
          start: DateTime.now().add(const Duration(hours: 2)),
          end: DateTime.now().add(const Duration(hours: 4)),
          description: 'MatchUp activity — check the app for details.',
          location: 'Community Sports Centre, Court 3',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Added to calendar' : 'Could not add to calendar',
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Add to Calendar',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/check-in/$activityId'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.glowPrimary,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: SvgPicture.asset(
                'assets/images/discovery/icons/check_circle.svg',
                width: 16,
                height: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Check In',
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
}
