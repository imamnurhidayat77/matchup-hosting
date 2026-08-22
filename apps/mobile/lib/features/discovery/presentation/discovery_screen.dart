import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../tour/presentation/tour_anchors.dart';
import '../domain/activity_model.dart';
import 'widgets/discovery_actions.dart';
import 'widgets/swipe_deck.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final all = await ref.watch(notificationRepositoryProvider).all();
  return all.where((n) => n.unread).length;
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  int _topIndex = 0;

  /// Fallback data shown immediately on first frame while the repository
  /// load is in flight. Replaced once the network/dummy repo returns.
  late List<ActivityModel> _activities = _seed();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(activityRepositoryProvider).feed();
      if (mounted && list.isNotEmpty) {
        setState(() => _activities = list);
      }
    } catch (_) {
      // Repository already falls back internally; keep seed for safety.
    }
  }

  static List<ActivityModel> _seed() {
    final now = DateTime.now();
    final tomorrow4pm = DateTime(now.year, now.month, now.day + 1, 16);
    return <ActivityModel>[
      ActivityModel(
        id: '1',
        title: 'Saturday Afternoon 5v5 Basketball',
        sportType: 'Basketball',
        description:
            'Looking for intermediate players to join us for some friendly '
            "5v5 runs. Let's have fun!",
        location: 'Riverside Court',
        distanceKm: 2.4,
        dateTime: tomorrow4pm,
        durationMinutes: 120,
        skillLevel: 'Intermediate',
        capacity: 10,
        participantCount: 6,
        hostName: 'Michael Torres',
        hostRating: 4.8,
        hostGamesCount: 32,
        coverImageUrl: 'assets/images/discovery/covers/basketball_1.png',
        status: ActivityStatus.available,
        vibeTags: const ['Friendly people', 'Great vibes', 'Arrive 15m early'],
      ),
      ActivityModel(
        id: '2',
        title: 'Weekend Tennis Doubles',
        sportType: 'Tennis',
        description:
            'Looking for doubles partners for a weekend match at Central Park '
            'courts. Bring your own racket.',
        location: 'Central Park Courts',
        distanceKm: 1.2,
        dateTime: now.add(const Duration(days: 1, hours: 2)),
        durationMinutes: 90,
        skillLevel: 'Intermediate',
        capacity: 8,
        participantCount: 4,
        hostName: 'Sarah Chen',
        hostRating: 4.9,
        hostGamesCount: 41,
        coverImageUrl: 'assets/images/discovery/covers/tennis_5.png',
        status: ActivityStatus.available,
        vibeTags: const ['Competitive', 'Bring water'],
      ),
      ActivityModel(
        id: '3',
        title: 'Trail Run Saturday',
        sportType: 'Running',
        description:
            '8km trail run through the park. Casual pace, group of mixed '
            'experience levels. Coffee after.',
        location: 'Forest Trail Park',
        distanceKm: 5.6,
        dateTime: now.add(const Duration(days: 4, hours: 7)),
        durationMinutes: 60,
        skillLevel: 'Beginner',
        capacity: 8,
        participantCount: 3,
        hostName: 'Tyler Vance',
        hostRating: 4.7,
        hostGamesCount: 18,
        coverImageUrl: 'assets/images/discovery/covers/basketball_3.png',
        status: ActivityStatus.available,
        vibeTags: const ['Friendly people', 'Coffee after'],
      ),
    ];
  }

  void _swipeOut(bool liked) {
    if (_topIndex >= _activities.length) return;
    HapticFeedback.lightImpact();
    final activity = _activities[_topIndex];
    final next = _topIndex + 1;
    setState(() => _topIndex = next);
    if (liked && next < _activities.length) {
      // Let the exit animation finish (~320ms) before navigating so the
      // match screen doesn't cut the card mid-flight.
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) context.go('/match/${activity.id}');
      });
    }
  }

  void _dislike() => _swipeOut(false);
  void _like() => _swipeOut(true);

  void _reset() => setState(() => _topIndex = 0);

  void _openDetails() {
    if (_topIndex >= _activities.length) return;
    final activity = _activities[_topIndex];
    // push (not go): go() replaces the whole navigation stack, which leaves
    // the detail screen's back/dislike buttons (Navigator.maybePop) with
    // nothing to pop — they'd register the tap but do nothing visible.
    context.push('/activity/${activity.id}');
  }

  @override
  Widget build(BuildContext context) {
    final deckExhausted = _topIndex >= _activities.length;
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;

    return AppScaffold(
      showHomeIndicator: false, // inside ShellRoute — AppShell draws its own.
      body: Column(
        children: [
          HomeHeader(
            title: 'Discover',
            subtitle: 'Find your next game',
            actions: [
              HomeHeaderAction(
                icon: Icons.tune_rounded,
                semanticLabel: 'Filters',
                onTap: () => context.push('/filter'),
                anchorKey: TourAnchors.filterButton,
              ),
              HomeHeaderAction(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Notifications',
                onTap: () => context.push('/notifications'),
                showDot: unreadCount > 0,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x2,
                AppSpacing.x5,
                AppSpacing.x2,
              ),
              // Tapping the card opens details — a natural gesture that
              // mirrors how the like/dismiss buttons mirror the swipe.
              child: deckExhausted
                  ? DiscoveryEmptyDeck(onRestart: _reset)
                  // KeyedSubtree carries the tour anchor so SwipeDeck keeps
                  // its own `ValueKey(_topIndex)` (needed to force a fresh
                  // State per card — see its comment below) instead of the
                  // anchor key overwriting it.
                  : KeyedSubtree(
                      key: TourAnchors.swipeDeck,
                      child: PressableScale(
                        onTap: _openDetails,
                        child: SwipeDeck(
                          // Force a fresh State each time topIndex advances
                          // so no listener/AnimationController from the
                          // previous card can interfere with the next swipe.
                          key: ValueKey(_topIndex),
                          activities: _activities,
                          topIndex: _topIndex,
                          onSwiped: _swipeOut,
                        ),
                      ),
                    ),
            ),
          ),
          if (!deckExhausted)
            Padding(
              key: TourAnchors.actionRow,
              padding: const EdgeInsets.only(
                top: AppSpacing.x2,
                bottom: AppSpacing.x4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiscoveryAction.reject(onTap: _dislike),
                  const SizedBox(width: AppSpacing.x6),
                  DiscoveryAction.info(onTap: _openDetails),
                  const SizedBox(width: AppSpacing.x6),
                  DiscoveryAction.join(onTap: _like),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
