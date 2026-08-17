import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_bar_mock.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _tabIndex = 0;
  late final List<_Notif> _all;

  @override
  void initState() {
    super.initState();
    _all = [
      _Notif('Sarah Chen', 'I brought extra tennis balls!', '10 min ago', _NotifType.chat, unread: true),
      _Notif('Weekend Soccer Match starting in 2 hours', '', '30 min ago', _NotifType.activity, unread: true),
      _Notif('Welcome to MatchUp!', 'Start by setting your preferences', '1 hour ago', _NotifType.system),
      _Notif('Alex wants to join your basketball game', '', '2 hours ago', _NotifType.request),
      _Notif('Your report was resolved', 'The reported activity has been removed', 'Yesterday', _NotifType.moderation),
      _Notif('Mike tagged you in a volleyball match', '', 'Yesterday', _NotifType.activity),
      _Notif('New activity near you', 'Sunset Basketball 5v5 in Brooklyn', '2 days ago', _NotifType.activity),
    ];
  }

  List<_Notif> get _visible =>
      _tabIndex == 0 ? _all.where((n) => n.unread).toList() : _all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const StatusBarMock(foreground: AppColors.textPrimary),
            _Header(onBack: () => context.go('/discovery')),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: _SegmentedTabs(
                index: _tabIndex,
                onChange: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _visible.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _NotifCard(item: _visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/discovery/icons/arrow_left.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Notifications',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _seg(label: 'Unread', i: 0),
          _seg(label: 'All', i: 1),
        ],
      ),
    );
  }

  Widget _seg({required String label, required int i}) {
    final selected = i == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChange(i),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: selected ? AppColors.primaryDarker : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.item});

  final _Notif item;

  @override
  Widget build(BuildContext context) {
    final c = item.type.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.unread ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(
                item.type.iconAsset,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 14,
                    fontWeight: item.unread ? FontWeight.w700 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(item.time, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (item.unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/discovery/icons/notification.svg',
            width: 56,
            height: 56,
            colorFilter: const ColorFilter.mode(
              AppColors.textTertiary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),
          Text("You're all caught up", style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text(
            'New notifications will show up here.',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _NotifType {
  chat,
  activity,
  system,
  request,
  moderation;

  Color get color {
    switch (this) {
      case _NotifType.chat:
        return AppColors.primary;
      case _NotifType.activity:
        return AppColors.accent;
      case _NotifType.system:
        return AppColors.success;
      case _NotifType.request:
        return AppColors.warning;
      case _NotifType.moderation:
        return AppColors.error;
    }
  }

  String get iconAsset {
    switch (this) {
      case _NotifType.chat:
        return 'assets/images/discovery/icons/message_square.svg';
      case _NotifType.activity:
        return 'assets/images/discovery/icons/calendar.svg';
      case _NotifType.system:
        return 'assets/images/discovery/icons/check_circle.svg';
      case _NotifType.request:
        return 'assets/images/discovery/icons/users.svg';
      case _NotifType.moderation:
        return 'assets/images/discovery/icons/alert_circle.svg';
    }
  }
}

class _Notif {
  _Notif(this.title, this.subtitle, this.time, this.type, {this.unread = false});

  final String title;
  final String subtitle;
  final String time;
  final _NotifType type;
  final bool unread;
}
