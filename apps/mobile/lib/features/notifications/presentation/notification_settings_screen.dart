import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Persists each toggle as `notif_<key>` in SharedPreferences.
/// Default values mirror the mock (most on, a few off).
final _notifSettingsProvider =
    StateNotifierProvider<_NotifSettingsNotifier, Map<String, bool>>((ref) {
  return _NotifSettingsNotifier();
});

class _NotifSettingsNotifier extends StateNotifier<Map<String, bool>> {
  _NotifSettingsNotifier()
      : super(_defaults) {
    _load();
  }

  static const _defaults = <String, bool>{
    'new_game_nearby': true,
    'game_reminders': true,
    'game_cancellations': true,
    'new_messages': true,
    'friend_requests': false,
    'game_invitations': true,
    'weekly_summary': true,
    'rating_received': true,
    'milestone_achievements': false,
    'promotions': false,
    'app_updates': true,
  };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = Map<String, bool>.from(_defaults);
    for (final key in _defaults.keys) {
      final stored = prefs.getBool('notif_$key');
      if (stored != null) loaded[key] = stored;
    }
    state = loaded;
  }

  Future<void> toggle(String key) async {
    final next = !( state[key] ?? false);
    state = {...state, key: next};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', next);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_notifSettingsProvider);
    final notifier = ref.read(_notifSettingsProvider.notifier);

    return AppScaffold.detail(
      title: 'Notifications',
      showHomeIndicator: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x4,
          AppSpacing.x5,
          AppSpacing.x8,
        ),
        children: [
          Text(
            'Choose what alerts you want to receive',
            style: AppTypography.bodyMedium(context).copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          _Section(
            label: 'GAME UPDATES',
            children: [
              _ToggleRow(
                title: 'New Game Nearby',
                subtitle: 'Alert me when a sport I play is hosted nearby',
                value: settings['new_game_nearby'] ?? true,
                onChanged: () => notifier.toggle('new_game_nearby'),
              ),
              _ToggleRow(
                title: 'Game Reminders',
                subtitle: 'Remind me of upcoming matches I joined',
                value: settings['game_reminders'] ?? true,
                onChanged: () => notifier.toggle('game_reminders'),
              ),
              _ToggleRow(
                title: 'Game Cancellations',
                subtitle: 'Notify instantly if a game gets cancelled',
                value: settings['game_cancellations'] ?? true,
                onChanged: () => notifier.toggle('game_cancellations'),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),

          _Section(
            label: 'SOCIAL ACTIVITY',
            children: [
              _ToggleRow(
                title: 'New Messages',
                subtitle: 'When players chat in active game threads',
                value: settings['new_messages'] ?? true,
                onChanged: () => notifier.toggle('new_messages'),
              ),
              _ToggleRow(
                title: 'Friend Requests',
                subtitle: 'Alert me when someone wants to connect',
                value: settings['friend_requests'] ?? false,
                onChanged: () => notifier.toggle('friend_requests'),
              ),
              _ToggleRow(
                title: 'Game Invitations',
                subtitle: 'When hosts invite me to play in their match',
                value: settings['game_invitations'] ?? true,
                onChanged: () => notifier.toggle('game_invitations'),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),

          _Section(
            label: 'MY ACTIVITY',
            children: [
              _ToggleRow(
                title: 'Weekly Summary',
                subtitle:
                    'A roundup of games played, stats and rating highlights',
                value: settings['weekly_summary'] ?? true,
                onChanged: () => notifier.toggle('weekly_summary'),
              ),
              _ToggleRow(
                title: 'Rating Received',
                subtitle: 'Alert me when other players rate my play',
                value: settings['rating_received'] ?? true,
                onChanged: () => notifier.toggle('rating_received'),
              ),
              _ToggleRow(
                title: 'Milestone Achievements',
                subtitle: 'Get notified when unlocking medals & streaks',
                value: settings['milestone_achievements'] ?? false,
                onChanged: () => notifier.toggle('milestone_achievements'),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),

          _Section(
            label: 'PRODUCT & NEWS',
            children: [
              _ToggleRow(
                title: 'Promotions & Offers',
                subtitle:
                    'Special offers, partnership events, and gear discounts',
                value: settings['promotions'] ?? false,
                onChanged: () => notifier.toggle('promotions'),
              ),
              _ToggleRow(
                title: 'App Updates',
                subtitle:
                    'Be the first to know about new sports and feature additions',
                value: settings['app_updates'] ?? true,
                onChanged: () => notifier.toggle('app_updates'),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.metaSub(context).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
            color: context.colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── Toggle row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: '$title: ${value ? 'enabled' : 'disabled'}',
          toggled: value,
          child: InkWell(
            onTap: onChanged,
            borderRadius: last
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.card),
                    bottomRight: Radius.circular(AppRadius.card),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.labelField(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.metaSub(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Switch.adaptive(
                    value: value,
                    onChanged: (_) => onChanged(),
                    activeThumbColor: Colors.white,
                    activeTrackColor: context.colors.primaryOnSurface,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: context.colors.border,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            color: context.colors.border,
            indent: AppSpacing.x4,
            endIndent: AppSpacing.x4,
          ),
      ],
    );
  }
}
