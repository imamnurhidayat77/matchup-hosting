import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../../../core/widgets/home_indicator.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _bgSurface = Color(0xFFF8FAFC);
const _greenDark = Color(0xFF097044);
const _greenLightBg = Color(0xFFD1FAE5);
const _errorText = Color(0xFFCC3333);

class JoinedActivityDetailScreen extends StatelessWidget {
  final String activityId;

  const JoinedActivityDetailScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const StatusBarMock(foreground: AppColors.textPrimary),
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hero(context),
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
                            child: GestureDetector(
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'Leave Activity',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: _errorText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
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
          _circleBtn(
            'assets/images/discovery/icons/arrow_left.svg',
            Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
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
          _circleBtn('assets/images/discovery/icons/more_horizontal.svg', Icons.more_horiz),
        ],
      ),
    );
  }

  Widget _circleBtn(String asset, IconData fallback, {VoidCallback? onTap}) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _bgSurface,
            borderRadius: BorderRadius.circular(100),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 20,
            height: 20,
            child: SvgPicture.asset(asset, width: 20, height: 20),
          ),
        ),
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
          Container(color: const Color.fromRGBO(0, 0, 0, 0.15)),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _greenDark,
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
        _badge('Basketball', _primaryLight, _primaryDarker),
        const SizedBox(width: 8),
        _badge('CONFIRMED', _greenLightBg, _greenDark),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailItem({
    required String icon,
    required String title,
    required String sub,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(100),
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 18,
              height: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sub,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaChips() {
    return Row(
      children: [
        _metaChip('zap.svg', 'Intermediate', AppColors.textPrimary),
        const SizedBox(width: 8),
        _metaChip('dollar_sign.svg', 'Free', _greenDark),
      ],
    );
  }

  Widget _metaChip(String icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSurface,
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
                  color: _primaryDarker,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                _avatar('avatar_1.png'),
                _avatar('avatar_2.png', overlap: 10),
                _avatar('avatar_3.png', overlap: 10),
                _avatar('avatar_4.png', overlap: 10),
                _avatar('avatar_5.png', overlap: 10),
                _moreAvatar('+1', overlap: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String asset, {double overlap = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: overlap),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: ClipOval(
          child: AssetImageWithFallback(
            assetPath: 'assets/images/discovery/avatars/$asset',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            isAvatar: true,
          ),
        ),
      ),
    );
  }

  Widget _moreAvatar(String label, {double overlap = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: overlap),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.border,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
          color: _bgSurface,
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
            color: _bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _chatMsg(
                avatar: 'msg_alex.png',
                sender: 'Alex Mercer',
                time: '10:14 AM',
                text: 'Bringing the basketball pump just in case. See you guys at 4!',
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
                color: _primaryDarker,
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
            content: Text(ok
                ? 'Added to calendar'
                : 'Could not add to calendar'),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
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
              color: Color.fromRGBO(45, 127, 249, 0.2),
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