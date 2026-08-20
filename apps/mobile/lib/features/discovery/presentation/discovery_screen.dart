import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/notification_icon_button.dart';
import '../domain/activity_model.dart';

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
    return <ActivityModel>[
      ActivityModel(
        id: '1',
        title: 'Sunset Basketball 5v5',
        sportType: 'Basketball',
        description:
            'Join us for a fun 5v5 pickup basketball game at sunset. All skill levels welcome, but intermediate play expected. Bring water and good vibes!',
        location: 'Brooklyn Public Courts',
        distanceKm: 2.5,
        dateTime: now.add(const Duration(hours: 4)),
        skillLevel: 'Intermediate',
        capacity: 12,
        participantCount: 8,
        hostName: 'James Wilson',
        coverImageUrl: 'assets/images/discovery/covers/basketball_1.png',
        status: ActivityStatus.available,
      ),
      ActivityModel(
        id: '2',
        title: 'Weekend Tennis Doubles',
        sportType: 'Tennis',
        description:
            'Looking for doubles partners for a weekend match at Central Park courts. Bring your own racket.',
        location: 'Central Park Courts',
        distanceKm: 1.2,
        dateTime: now.add(const Duration(days: 1, hours: 2)),
        skillLevel: 'Intermediate',
        capacity: 8,
        participantCount: 4,
        hostName: 'Sarah Chen',
        coverImageUrl: 'assets/images/discovery/covers/tennis_5.png',
        status: ActivityStatus.available,
      ),
      ActivityModel(
        id: '3',
        title: 'Trail Run Saturday',
        sportType: 'Running',
        description:
            '8km trail run through the park. Casual pace, group of mixed experience levels. Coffee after.',
        location: 'Forest Trail Park',
        distanceKm: 5.6,
        dateTime: now.add(const Duration(days: 4, hours: 7)),
        skillLevel: 'Intermediate',
        capacity: 8,
        participantCount: 3,
        hostName: 'Tyler Vance',
        coverImageUrl: 'assets/images/discovery/covers/basketball_3.png',
        status: ActivityStatus.available,
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

  /// Returns true when the previous card was restored.
  bool _undo() {
    if (_topIndex == 0 || _topIndex > _activities.length) return false;
    HapticFeedback.selectionClick();
    setState(() => _topIndex -= 1);
    return true;
  }

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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Discover',
                      style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  NotificationIconButton(
                    onTap: () => context.go('/notifications'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Single compact subtitle — avoids repeating the
                        // screen's purpose across two lines.
                        Flexible(
                          child: Text(
                            'Activities near you',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Preferences',
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.go('/preferences'),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/preferences.svg',
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
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: deckExhausted
                    ? _EmptyDeck(
                        onRestart: _reset,
                        onAdjustPreferences: () => context.go('/preferences'),
                      )
                    : _SwipeDeck(
                        // Force a fresh State each time topIndex advances so no
                        // listener/AnimationController from the previous card
                        // can interfere with the next swipe.
                        key: ValueKey(_topIndex),
                        activities: _activities,
                        topIndex: _topIndex,
                        onSwiped: _swipeOut,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: deckExhausted
                    ? [
                        TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Start over'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ]
                    : [
                        _ActionButton(
                          icon: Icons.close,
                          iconAsset:
                              'assets/images/discovery/icons/x_circle.svg',
                          color: AppColors.surface,
                          iconColor: AppColors.danger,
                          size: 60,
                          iconSize: 28,
                          onTap: _dislike,
                          border: true,
                        ),
                        const SizedBox(width: 14),
                        _ActionButton(
                          icon: Icons.info_outline,
                          iconAsset:
                              'assets/images/discovery/icons/file_search.svg',
                          color: AppColors.surface,
                          iconColor: AppColors.primary,
                          size: 50,
                          iconSize: 24,
                          onTap: _openDetails,
                          border: true,
                        ),
                        const SizedBox(width: 14),
                        _ActionButton(
                          icon: Icons.favorite,
                          iconAsset: 'assets/images/discovery/icons/heart.svg',
                          color: AppColors.primary,
                          iconColor: Colors.white,
                          size: 60,
                          iconSize: 28,
                          onTap: _like,
                        ),
                        if (_topIndex > 0) ...[
                          const SizedBox(width: 14),
                          _UndoButton(onPressed: _undo),
                        ],
                      ],
              ),
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Compact visual, but padded to a 44×44 minimum touch target (HIG).
    return Semantics(
      label: 'Undo last swipe',
      button: true,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.undo, size: 22),
        color: AppColors.textSecondary,
        tooltip: 'Undo last swipe',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({
    required this.onRestart,
    required this.onAdjustPreferences,
  });

  final VoidCallback onRestart;
  final VoidCallback onAdjustPreferences;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore, size: 56, color: AppColors.primaryLight),
          const SizedBox(height: 16),
          Text(
            "You're all caught up",
            style: AppTypography.headlineSmall.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "You've seen all activities near you.\nCheck back later or widen your preferences.",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onAdjustPreferences,
            icon: const Icon(Icons.tune, size: 20),
            label: const Text('Adjust preferences'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          TextButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Start over'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({
    super.key,
    required this.activities,
    required this.topIndex,
    required this.onSwiped,
  });

  final List<ActivityModel> activities;
  final int topIndex;
  final void Function(bool liked) onSwiped;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck> with TickerProviderStateMixin {
  Offset _drag = Offset.zero;
  bool _animating = false;
  bool _thresholdReached = false;

  late final AnimationController _springController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<Offset> _exitAnimation;
  Offset _exitStart = Offset.zero;
  Offset _exitEnd = Offset.zero;

  @override
  void didUpdateWidget(covariant _SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topIndex != widget.topIndex && !_animating) {
      _drag = Offset.zero;
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_animating) return;
    setState(() => _drag += d.delta);
    // Subtle tick when crossing the commit threshold — confirms "release
    // now and it will count" without looking at the stamps.
    final threshold = MediaQuery.of(context).size.width * 0.25;
    final crossed = _drag.dx.abs() >= threshold;
    if (crossed && !_thresholdReached) {
      HapticFeedback.selectionClick();
      _thresholdReached = true;
    } else if (!crossed) {
      _thresholdReached = false;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_animating) return;
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.25;
    final vx = d.velocity.pixelsPerSecond.dx;
    final flingCommit = vx.abs() > 700 && vx.sign == _drag.dx.sign;
    if (_drag.dx > threshold || (_drag.dx > 0 && flingCommit)) {
      _animateOut(true, d.velocity.pixelsPerSecond);
    } else if (_drag.dx < -threshold || (_drag.dx < 0 && flingCommit)) {
      _animateOut(false, d.velocity.pixelsPerSecond);
    } else {
      _springBack();
    }
  }

  Future<void> _springBack() async {
    final start = _drag;
    final tween = Tween<Offset>(begin: start, end: Offset.zero);
    final animation = tween.animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (!mounted) return;
      setState(() => _drag = animation.value);
    }

    _springController.addListener(listener);
    setState(() => _animating = true);
    _springController.value = 0;
    await _springController.forward();
    _springController.removeListener(listener);
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _animating = false;
    });
  }

  Future<void> _animateOut(bool liked, Offset flingVelocity) async {
    _exitStart = _drag;
    final width = MediaQuery.of(context).size.width;
    final travelX = liked ? width * 1.4 : -width * 1.4;
    final exitVx = flingVelocity.dx.abs();
    final exitDurationMs = (320 - (exitVx.clamp(0, 1200) / 1200) * 120).round();
    _exitEnd = Offset(travelX, _drag.dy + 80);
    _exitController.duration = Duration(milliseconds: exitDurationMs);
    final tween = Tween<Offset>(begin: _exitStart, end: _exitEnd);
    _exitAnimation = tween.animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (!mounted) return;
      setState(() => _drag = _exitAnimation.value);
    }

    _exitController.addListener(listener);
    setState(() => _animating = true);
    _exitController.value = 0;
    await _exitController.forward();
    _exitController.removeListener(listener);
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _animating = false;
    });
    widget.onSwiped(liked);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.activities;
    final top = items[widget.topIndex];
    final next = items[(widget.topIndex + 1).clamp(0, items.length - 1)];
    final afterNext = items[(widget.topIndex + 2).clamp(0, items.length - 1)];

    final dragX = _drag.dx;
    final absDrag = dragX.abs();
    final progress = (absDrag / 320).clamp(0.0, 1.0);
    final rotation = dragX / 1000;
    final likeOpacity = (dragX / 120).clamp(0.0, 1.0);
    final nopeOpacity = (-dragX / 120).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final nextScale = lerpDouble(0.95, 1.0, progress)!;
        final nextOpacity = lerpDouble(0.85, 1.0, progress)!;
        final nextOffset = lerpDouble(16.0, 0.0, progress)!;
        final afterScale = lerpDouble(0.88, 0.95, progress)!;
        final afterOpacity = lerpDouble(0.55, 0.85, progress)!;
        final afterOffset = lerpDouble(32.0, 16.0, progress)!;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, afterOffset),
                child: Transform.scale(
                  scale: afterScale,
                  child: Opacity(
                    opacity: afterOpacity,
                    child: _SwipeCard(activity: afterNext),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, nextOffset),
                child: Transform.scale(
                  scale: nextScale,
                  child: Opacity(
                    opacity: nextOpacity,
                    child: _SwipeCard(activity: next),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Semantics(
                label:
                    'Activity card. Swipe right to like, left to pass. '
                    'Use the action buttons below as an alternative to swiping.',
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Stack(
                        children: [
                          _SwipeCard(activity: top),
                          if (likeOpacity > 0)
                            Positioned(
                              top: 28,
                              left: 28,
                              child: Opacity(
                                opacity: likeOpacity,
                                child: _StampBadge(
                                  label: 'LIKE',
                                  color: AppColors.likeGreen,
                                  rotation: -0.2,
                                ),
                              ),
                            ),
                          if (nopeOpacity > 0)
                            Positioned(
                              top: 28,
                              right: 28,
                              child: Opacity(
                                opacity: nopeOpacity,
                                child: _StampBadge(
                                  label: 'NOPE',
                                  color: AppColors.nopeRed,
                                  rotation: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ); // closes outer Stack
      }, // builder
    ); // LayoutBuilder
  }
}

class _StampBadge extends StatelessWidget {
  const _StampBadge({
    required this.label,
    required this.color,
    required this.rotation,
  });
  final String label;
  final Color color;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final cover = activity.coverImageUrl;
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2D7FF9),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.asset(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primaryLight,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.sports_basketball,
                          size: 80,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.primaryLight,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.sports_basketball,
                        size: 80,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            activity.sportType.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: const Color(0x99000000),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/discovery/icons/map_pin.svg',
                                  width: 12,
                                  height: 12,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${activity.distanceKm.toStringAsFixed(1)} km away',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activity.title,
                    style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _PillChip(
                        icon: 'assets/images/discovery/icons/zap.svg',
                        label: activity.skillLevel,
                        bg: AppColors.background,
                        fg: AppColors.primaryDarker,
                      ),
                      _PillChip(
                        icon: 'assets/images/discovery/icons/clock.svg',
                        label: 'Today, 6:30 PM',
                        bg: AppColors.background,
                        fg: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    activity.description,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      height: 1.6,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _avatarStack(activity.participantCount),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${activity.participantCount} / ${activity.capacity} spots',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 60,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      activity.participantCount /
                                      activity.capacity,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activity.status == ActivityStatus.almostFull
                              ? 'Almost Full'
                              : 'Open',
                          style: const TextStyle(
                            color: Color(0xFF04694A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
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

  Widget _avatarStack(int count) {
    final colors = [AppColors.primary, const Color(0xFF097044)];
    final initials = ['M', 'J'];
    return SizedBox(
      width: 86,
      height: 30,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                  color: i == 0
                      ? AppColors.background
                      : colors[(i - 1).clamp(0, colors.length - 1)],
                ),
                child: i == 0
                    ? ClipOval(
                        child: Image.asset(
                          'assets/images/discovery/avatars/avatar_1.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          initials[(i - 1).clamp(0, initials.length - 1)],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            width: 13,
            height: 13,
            colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.iconAsset,
    required this.color,
    required this.iconColor,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.border = false,
  });

  final IconData icon;
  final String iconAsset;
  final Color color;
  final Color iconColor;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        // Visual size stays as designed, but the tap target never goes
        // below the 44×44 accessibility minimum (HIG / Material).
        constraints: BoxConstraints(
          minWidth: size < 44 ? 44 : size,
          minHeight: size < 44 ? 44 : size,
        ),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
        icon: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: AppColors.border) : null,
            boxShadow: [
              BoxShadow(
                color: iconColor == Colors.white
                    ? AppColors.glowPrimary
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
