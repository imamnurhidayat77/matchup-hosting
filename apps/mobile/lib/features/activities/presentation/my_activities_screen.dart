import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../discovery/domain/activity_model.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  final _upcoming = [
    _ActivityItem(
      title: 'Sunset Basketball 5v5',
      sportType: 'Basketball',
      location: 'Victoria Park Courts',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      status: ActivityStatus.joined,
      capacity: 10,
      participantCount: 6,
    ),
    _ActivityItem(
      title: 'Morning Yoga Session',
      sportType: 'Yoga',
      location: 'Mission Bay Beach',
      dateTime: DateTime.now().add(const Duration(days: 3)),
      status: ActivityStatus.joined,
      capacity: 20,
      participantCount: 12,
    ),
  ];

  final _hosting = [
    _ActivityItem(
      title: 'Weekend Soccer Match',
      sportType: 'Soccer',
      location: 'Auckland Domain',
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 4)),
      status: ActivityStatus.hosted,
      capacity: 10,
      participantCount: 8,
    ),
  ];

  final _past = [
    _ActivityItem(
      title: 'Trail Running Group',
      sportType: 'Running',
      location: 'Mount Eden Summit',
      dateTime: DateTime.now().subtract(const Duration(days: 5)),
      status: ActivityStatus.past,
      capacity: 15,
      participantCount: 10,
    ),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('My Activities', style: AppTypography.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerHeight: 0,
                  labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Hosting'),
                    Tab(text: 'Past'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_upcoming),
                  _buildList(_hosting),
                  _buildList(_past),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_ActivityItem> activities) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No activities yet', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Join or create an activity to see it here',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityCard(
          activity: activity,
          onTap: () => context.push('/activity/$index'),
        );
      },
    );
  }
}

class _ActivityItem {
  final String title;
  final String sportType;
  final String location;
  final DateTime dateTime;
  final ActivityStatus status;
  final int capacity;
  final int participantCount;

  _ActivityItem({
    required this.title,
    required this.sportType,
    required this.location,
    required this.dateTime,
    required this.status,
    required this.capacity,
    required this.participantCount,
  });
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  Color get _statusColor {
    switch (activity.status) {
      case ActivityStatus.joined:
        return AppColors.primary;
      case ActivityStatus.hosted:
        return AppColors.accent;
      case ActivityStatus.past:
        return AppColors.textTertiary;
      default:
        return AppColors.success;
    }
  }

  String get _statusText {
    switch (activity.status) {
      case ActivityStatus.joined:
        return 'Joined';
      case ActivityStatus.hosted:
        return 'Hosting';
      case ActivityStatus.past:
        return 'Completed';
      default:
        return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText,
                      style: AppTypography.caption.copyWith(color: _statusColor),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, h:mm a').format(activity.dateTime),
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(activity.title, style: AppTypography.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.sports, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(activity.sportType, style: AppTypography.bodyMedium),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.location,
                      style: AppTypography.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.participantCount}/${activity.capacity} participants',
                    style: AppTypography.bodyMedium,
                  ),
                  const Spacer(),
                  if (activity.status == ActivityStatus.hosted)
                    TextButton(
                      onPressed: () {},
                      child: const Text('Manage'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
