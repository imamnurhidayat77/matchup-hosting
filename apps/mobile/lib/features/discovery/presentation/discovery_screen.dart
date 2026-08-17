import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../domain/activity_model.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int _topIndex = 0;

  final List<ActivityModel> _activities = [
    ActivityModel(
      id: '1',
      title: 'Sunset Basketball 5v5',
      sportType: 'Basketball',
      description:
          'Join us for a fun 5v5 pickup basketball game at sunset. All skill levels welcome, but intermediate play expected. Bring water and good vibes!',
      location: 'Brooklyn Public Courts',
      distanceKm: 2.5,
      dateTime: DateTime.now().add(const Duration(hours: 4)),
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
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      skillLevel: 'Intermediate',
      capacity: 4,
      participantCount: 2,
      hostName: 'Sarah Chen',
      coverImageUrl: 'assets/images/discovery/covers/tennis_5.png',
      status: ActivityStatus.available,
    ),
    ActivityModel(
      id: '3',
      title: 'Morning Beach Volleyball',
      sportType: 'Volleyball',
      description:
          'Casual beach volleyball, all levels welcome. We play every Sunday morning at Sunset Beach.',
      location: 'Sunset Beach Court',
      distanceKm: 4.8,
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 8)),
      skillLevel: 'All Level',
      capacity: 10,
      participantCount: 6,
      hostName: 'Mike Chen',
      coverImageUrl: 'assets/images/discovery/sports/volleyball.png',
      status: ActivityStatus.available,
    ),
    ActivityModel(
      id: '4',
      title: 'Friday Night Soccer 6v6',
      sportType: 'Soccer',
      description:
          'Friendly soccer game every Friday night. Co-ed, all skill levels. We rotate teams every game.',
      location: 'Riverside Field',
      distanceKm: 3.1,
      dateTime: DateTime.now().add(const Duration(days: 3, hours: 6)),
      skillLevel: 'Beginner',
      capacity: 12,
      participantCount: 10,
      hostName: 'Lisa Park',
      coverImageUrl: 'assets/images/discovery/covers/basketball_2.png',
      status: ActivityStatus.almostFull,
    ),
    ActivityModel(
      id: '5',
      title: 'Trail Run Saturday',
      sportType: 'Running',
      description:
          '8km trail run through the park. Casual pace, group of mixed experience levels. Coffee after.',
      location: 'Forest Trail Park',
      distanceKm: 5.6,
      dateTime: DateTime.now().add(const Duration(days: 4, hours: 7)),
      skillLevel: 'Intermediate',
      capacity: 8,
      participantCount: 3,
      hostName: 'Tyler Vance',
      coverImageUrl: 'assets/images/discovery/covers/basketball_3.png',
      status: ActivityStatus.available,
    ),
  ];

  void _swipeOut(bool liked) {
    final next = (_topIndex + 1) % _activities.length;
    final activity = _activities[_topIndex];
    setState(() => _topIndex = next);
    if (liked) {
      Future.microtask(() {
        if (mounted) context.go('/match/${activity.id}');
      });
    }
  }

  void _dislike() => _swipeOut(false);
  void _like() => _swipeOut(true);

  void _openDetails() {
    final activity = _activities[_topIndex];
    context.go('/activity/${activity.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const StatusBarMock(foreground: AppColors.textPrimary),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discover', style: AppTypography.headlineSmall.copyWith(fontSize: 22)),
                    Semantics(
                      label: 'Notifications',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.go('/notifications'),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/images/discovery/icons/notification.svg',
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Find your match',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primaryDarker,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('•', style: AppTypography.bodyMedium),
                          Flexible(
                            child: Text(
                              'Activities near you',
                              style: AppTypography.bodyMedium,
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
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _SwipeDeck(
                  activities: _activities,
                  topIndex: _topIndex,
                  onSwiped: (liked) => _swipeOut(liked),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.close,
                    iconAsset: 'assets/images/discovery/icons/x_circle.svg',
                    color: AppColors.surface,
                    iconColor: const Color(0xFFCC3333),
                    size: 60,
                    iconSize: 28,
                    onTap: _dislike,
                    border: true,
                  ),
                  const SizedBox(width: 20),
                  _ActionButton(
                    icon: Icons.info_outline,
                    iconAsset: 'assets/images/discovery/icons/file_search.svg',
                    color: AppColors.surface,
                    iconColor: AppColors.primary,
                    size: 50,
                    iconSize: 24,
                    onTap: _openDetails,
                    border: true,
                  ),
                  const SizedBox(width: 20),
                  _ActionButton(
                    icon: Icons.favorite,
                    iconAsset: 'assets/images/discovery/icons/heart.svg',
                    color: AppColors.primary,
                    iconColor: Colors.white,
                    size: 60,
                    iconSize: 28,
                    onTap: _like,
                  ),
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

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({
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

class _SwipeDeckState extends State<_SwipeDeck>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  // Smoothed pointer velocity in pixels/second, tracked for fling awareness.
  Offset _velocity = Offset.zero;
  bool _animating = false;

  late final AnimationController _springController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    if (_animating) return;
    _velocity = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_animating) return;
    // Estimate instantaneous velocity (px/ms → px/s) and blend with the
    // previous sample for smoothing.
    final instant = Offset(d.delta.dx * 1000, d.delta.dy * 1000);
    setState(() {
      _drag += d.delta;
      _velocity = _velocity * 0.6 + instant * 0.4;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_animating) return;
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.25;
    final vx = _velocity.dx;
    final vxCommit = vx.abs() > 600 && _drag.dx.sign == vx.sign;
    if (_drag.dx > threshold || (_drag.dx > 0 && vxCommit)) {
      _animateOut(true);
    } else if (_drag.dx < -threshold || (_drag.dx < 0 && vxCommit)) {
      _animateOut(false);
    } else {
      _springBack();
    }
  }

  Future<void> _springBack() async {
    final start = _drag;
    final tween = Tween(begin: start, end: Offset.zero);
    final curve = CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutCubic,
    );
    void listener() {
      setState(() {
        _drag = tween.transform(curve.value);
      });
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

  Future<void> _animateOut(bool liked) async {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final start = _drag;
    final end = Offset(
      liked ? 800 : -800,
      _drag.dy + (_velocity.dy.abs() > 50 ? _drag.dy * 0.3 : 60),
    );
    final tween = Tween(begin: start, end: end);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    setState(() => _animating = true);
    void listener() {
      if (!mounted) return;
      setState(() {
        _drag = tween.transform(curve.value);
      });
    }

    controller.addListener(listener);
    await controller.forward();
    controller.removeListener(listener);
    controller.dispose();
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
    final next = items[(widget.topIndex + 1) % items.length];
    final afterNext = items[(widget.topIndex + 2) % items.length];

    final dragX = _drag.dx;
    final absDrag = dragX.abs();
    // How far the top card has travelled toward the edge (0..1).
    final progress = (absDrag / 320).clamp(0.0, 1.0);
    final rotation = dragX / 1000;
    final likeOpacity = (dragX / 120).clamp(0.0, 1.0);
    final nopeOpacity = (-dragX / 120).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Stacked cards "rise" as the top card is dragged away, making the
        // pile feel alive and not just a static backdrop.
        final nextScale = lerpDouble(0.95, 1.0, progress)!;
        final nextOpacity = lerpDouble(0.85, 1.0, progress)!;
        final nextOffset = lerpDouble(16.0, 0.0, progress)!;
        final afterScale = lerpDouble(0.88, 0.95, progress)!;
        final afterOpacity = lerpDouble(0.55, 0.85, progress)!;
        final afterOffset = lerpDouble(32.0, 16.0, progress)!;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Bottom of the pile — smallest and most faded.
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
              child: GestureDetector(
                onPanStart: _onPanStart,
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
                                color: const Color(0xFF22C55E),
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
                                color: const Color(0xFFEF4444),
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
          ],
        );
      },
    );
  }
}

class _StampBadge extends StatelessWidget {
  const _StampBadge({required this.label, required this.color, required this.rotation});
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: const Color(0x99000000),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/images/discovery/icons/map_pin.svg',
                                width: 12,
                                height: 12,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13, height: 1.6),
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
                                widthFactor: activity.participantCount / activity.capacity,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activity.status == ActivityStatus.almostFull ? 'Almost Full' : 'Open',
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
                  color: i == 0 ? AppColors.background : colors[(i - 1).clamp(0, colors.length - 1)],
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
          SvgPicture.asset(icon, width: 13, height: 13, colorFilter: ColorFilter.mode(fg, BlendMode.srcIn)),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: AppColors.border) : null,
            boxShadow: [
              BoxShadow(
                color: iconColor == Colors.white
                    ? const Color(0x402D7FF9)
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