import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/notification_icon_button.dart';

class _JoinedActivity {
  const _JoinedActivity({
    required this.id,
    required this.sport,
    required this.title,
    required this.time,
    required this.participants,
    required this.image,
    required this.confirmed,
    this.status = _ActivityTab.upcoming,
  });
  final String id;
  final String sport;
  final String title;
  final String time;
  final String participants;
  final String image;
  final bool confirmed;
  final _ActivityTab status;
}

enum _ActivityTab { upcoming, past, hosting }

class JoinedActivitiesScreen extends StatefulWidget {
  const JoinedActivitiesScreen({super.key});

  @override
  State<JoinedActivitiesScreen> createState() => _JoinedActivitiesScreenState();
}

class _JoinedActivitiesScreenState extends State<JoinedActivitiesScreen> {
  int _selectedTab = 0;

  // Tab 0 = Upcoming (joined, not started), 1 = Past, 2 = Hosting.
  // Each tab routes to its own detail variant:
  //   Upcoming → /joined-activity/:id ("You're in!" banner)
  //   Past     → /past-activity/:id/review
  //   Hosting  → /manage-activity/:id (manage participants)
  static const _activities = [
    _JoinedActivity(
      id: '1',
      sport: 'BASKETBALL',
      title: 'Saturday Afternoon 5v5 Run',
      time: 'Today, 4:00 PM',
      participants: '6/10',
      image: 'basketball_1.png',
      confirmed: true,
    ),
    _JoinedActivity(
      id: '2',
      sport: 'TENNIS',
      title: 'Sunday Singles Play',
      time: 'Tomorrow, 10:00 AM',
      participants: '1/2',
      image: 'tennis_5.png',
      confirmed: false,
    ),
    _JoinedActivity(
      id: '3',
      sport: 'BASKETBALL',
      title: 'Prospect Park 3v3 Shootout',
      time: 'Sat, Aug 15 • 2:00 PM',
      participants: '8/8',
      image: 'basketball_2.png',
      confirmed: true,
      status: _ActivityTab.past,
    ),
    _JoinedActivity(
      id: '4',
      sport: 'BASKETBALL',
      title: 'Friendly 5v5 Run at Prospect',
      time: 'Sat, Aug 23 • 4:00 PM',
      participants: '6/10',
      image: 'basketball_3.png',
      confirmed: true,
      status: _ActivityTab.hosting,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    for (final a in _activities.where(
                      (a) => a.status.index == _selectedTab,
                    ))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _ActivityCard(item: a),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('My Activities', style: AppTypography.titleScreen),
              ),
              NotificationIconButton(
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _tabBtn(0, 'Upcoming'),
              _tabBtn(1, 'Past'),
              _tabBtn(2, 'Hosting'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? AppColors.primaryDarker
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final _JoinedActivity item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Route by tab variant: hosting → manage screen, past → review,
      // upcoming → joined detail with "You're in!" banner.
      onTap: () => switch (item.status) {
        _ActivityTab.hosting => context.push('/manage-activity/${item.id}'),
        _ActivityTab.past => context.push('/past-activity/${item.id}/review'),
        _ActivityTab.upcoming => context.push('/joined-activity/${item.id}'),
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.08),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/discovery/covers/${item.image}',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.sport,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryDarker,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: switch (item.status) {
                            _ActivityTab.hosting => AppColors.primaryLight,
                            _ActivityTab.past => AppColors.statusSuccessBg,
                            _ActivityTab.upcoming =>
                              item.confirmed
                                  ? AppColors.statusSuccessBg
                                  : AppColors.warningBg,
                          },
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          switch (item.status) {
                            _ActivityTab.hosting => 'HOSTING',
                            _ActivityTab.past => 'COMPLETED',
                            _ActivityTab.upcoming =>
                              item.confirmed ? 'CONFIRMED' : 'PENDING',
                          },
                          style: AppTypography.bodySmall.copyWith(
                            color: switch (item.status) {
                              _ActivityTab.hosting => AppColors.primaryDarker,
                              _ActivityTab.past => AppColors.statusSuccessText,
                              _ActivityTab.upcoming =>
                                item.confirmed
                                    ? AppColors.statusSuccessText
                                    : AppColors.warning,
                            },
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/clock.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.time,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/users.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.participants,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
