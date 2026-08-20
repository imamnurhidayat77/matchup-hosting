import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';

class _Participant {
  const _Participant({
    required this.name,
    required this.avatar,
    required this.skill,
    required this.joined,
    required this.isOrganizer,
  });
  final String name;
  final String avatar;
  final String skill;
  final String joined;
  final bool isOrganizer;
}

class ActivityParticipantsScreen extends StatelessWidget {
  final String activityId;

  const ActivityParticipantsScreen({super.key, required this.activityId});

  static const _participants = [
    _Participant(
      name: 'James Wilson',
      avatar: 'host_james.png',
      skill: 'Advanced',
      joined: 'Joined 5 days ago',
      isOrganizer: true,
    ),
    _Participant(
      name: 'Alex Mercer',
      avatar: 'avatar_alex.png',
      skill: 'Intermediate',
      joined: 'Joined 2 days ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Sarah Chen',
      avatar: 'msg_sarah.png',
      skill: 'Intermediate',
      joined: 'Joined 2 days ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Marcus Brodie',
      avatar: 'avatar_1.png',
      skill: 'Advanced',
      joined: 'Joined 1 day ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Daniel Kim',
      avatar: 'avatar_2.png',
      skill: 'Beginner',
      joined: 'Joined 18 hours ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Elena Rostova',
      avatar: 'avatar_3.png',
      skill: 'Intermediate',
      joined: 'Joined 5 hours ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Tyler Vance',
      avatar: 'avatar_4.png',
      skill: 'Intermediate',
      joined: 'Joined 2 hours ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Sofia Martinez',
      avatar: 'sarah_c2.png',
      skill: 'Advanced',
      joined: 'Joined 3 days ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Ryan Thompson',
      avatar: 'avatar_5.png',
      skill: 'Intermediate',
      joined: 'Joined 4 days ago',
      isOrganizer: false,
    ),
    _Participant(
      name: 'Mia Johnson',
      avatar: 'avatar_6.png',
      skill: 'Beginner',
      joined: 'Joined 5 days ago',
      isOrganizer: false,
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
            _header(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: _participants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ParticipantCard(item: _participants[i]),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Participants',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Basketball at Central Park',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primaryDarker,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10/12 spots filled',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '83% Full',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryDarker,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.border),
                  FractionallySizedBox(
                    widthFactor: 0.83,
                    child: Container(color: AppColors.primary),
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

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.item});
  final _Participant item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player-profile/${item.name}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isOrganizer ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isOrganizer ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/discovery/avatars/${item.avatar}',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isOrganizer) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                size: 10,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Organizer',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _skillChip(item.skill),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Basketball',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryDarker,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              item.joined,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
