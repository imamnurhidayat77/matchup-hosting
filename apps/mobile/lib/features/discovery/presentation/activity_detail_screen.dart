import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _activityDetailProvider = FutureProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
      return ref.watch(activityRepositoryProvider).byId(id);
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activityDetailProvider(activityId));
    return async.when(
      loading: () => _LoadingSkeleton(),
      error: (e, _) => Scaffold(
        body: ErrorRetry(
          message: 'Could not load activity details.',
          onRetry: () => ref.invalidate(_activityDetailProvider(activityId)),
        ),
      ),
      data: (activity) {
        if (activity == null) {
          return const Scaffold(
            body: Center(child: Text('Activity not found.')),
          );
        }
        return _DetailBody(activity: activity, activityId: activityId);
      },
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const SkeletonBox(width: double.infinity, height: 240, radius: 0),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 100, height: 28, radius: AppRadius.pill),
                SizedBox(height: AppSpacing.x3),
                SkeletonBox(width: double.infinity, height: 28),
                SizedBox(height: AppSpacing.x4),
                ListRowSkeleton(),
                SizedBox(height: AppSpacing.x3),
                ListRowSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail body ─────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.activity, required this.activityId});
  final ActivityModel activity;
  final String activityId;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _joining = false;
  final ScrollController _scrollController = ScrollController();

  // Whether the scroll view has more content below the visible viewport.
  // Starts true (assume there is more) so the fade never flashes hidden then
  // visible on first frame; corrected as soon as the layout settles.
  bool _hasMoreBelow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFadeVisibility);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateFadeVisibility(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateFadeVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFadeVisibility() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 4px slack so the fade clears right before the physical end, rather
    // than lingering on the last sub-pixel of scroll extent.
    final atBottom = position.pixels >= position.maxScrollExtent - 4;
    if (atBottom == _hasMoreBelow) {
      setState(() => _hasMoreBelow = !atBottom);
    }
  }

  Future<void> _onJoin() async {
    HapticFeedback.mediumImpact();
    setState(() => _joining = true);
    try {
      await ref.read(activityRepositoryProvider).join(widget.activityId);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AppSnackbar.show(
        context,
        message: 'You\'ve joined ${widget.activity.title}!',
        variant: AppSnackbarVariant.success,
      );
      context.go('/joined-activity/${widget.activityId}');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not join. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Hero + back/share
            _Hero(activity: a),

            // Scrollable content. While there's more to see below, the
            // bottom edge fades out so a partially visible line reads as
            // "keep scrolling" instead of the content abruptly stopping.
            // The fade clears once the user reaches the actual end.
            Expanded(
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: _hasMoreBelow
                      ? const [Colors.transparent, Colors.black]
                      : const [Colors.black, Colors.black],
                  stops: const [0.0, 0.06],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x6,
                    AppSpacing.x5,
                    AppSpacing.x6,
                    AppSpacing.x6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sport badge + title — tight group, badge tags the title.
                      _SportBadge(sport: a.sportType),
                      const SizedBox(height: AppSpacing.x2),
                      Text(a.title, style: AppTypography.titleScreen),
                      // Chip is a sub-attribute of the title, so it sits close.
                      const SizedBox(height: AppSpacing.x3),

                      // Skill chip
                      _SkillChip(level: a.skillLevel),
                      // Section break before the host block gets full breathing
                      // room, matched on the other side of the divider below.
                      const SizedBox(height: AppSpacing.x5),

                      // Host row
                      _HostRow(hostName: a.hostName),
                      const SizedBox(height: AppSpacing.x5),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: AppSpacing.x5),

                      // Meta: date + location
                      _MetaRow(
                        icon: 'calendar.svg',
                        title: _formatDate(a.dateTime),
                        sub: _formatTime(a.dateTime),
                      ),
                      // Two meta rows are one related pair, so this gap stays
                      // tighter than the section breaks around them.
                      const SizedBox(height: AppSpacing.x3),
                      // Figma 43:244/245 — venue name on top, street address below.
                      // Falls back to distance so the second line is never blank.
                      _MetaRow(
                        icon: 'map_pin.svg',
                        title: a.location,
                        sub:
                            a.addressLine ??
                            '${a.distanceKm.toStringAsFixed(1)} km away',
                      ),
                      const SizedBox(height: AppSpacing.x5),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: AppSpacing.x5),

                      // About
                      _Section(
                        title: 'About this Activity',
                        // Figma 43:248 — 14px with 21px leading (1.5); the one
                        // place the design deliberately loosens line height.
                        child: Text(
                          a.description,
                          style: AppTypography.bodyReading,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x5),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: AppSpacing.x5),

                      // Participants
                      _Section(
                        title: 'Participants',
                        trailing: Text(
                          '${a.participantCount} joined / ${a.capacity} total',
                          style: AppTypography.countAccent,
                        ),
                        child: _ParticipantAvatars(count: a.participantCount),
                      ),
                      const SizedBox(height: AppSpacing.x5),

                      // Report button
                      _ReportButton(activityId: widget.activityId),
                    ],
                  ),
                ),
              ),
            ),

            // Action bar
            _ActionBar(
              activity: widget.activity,
              joining: _joining,
              onDislike: () => Navigator.of(context).maybePop(),
              onJoin: _onJoin,
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => DateFormat('EEEE, MMMM d').format(dt);

  String _formatTime(DateTime dt) {
    final start = DateFormat('h:mm a').format(dt);
    final end = DateFormat('h:mm a').format(dt.add(const Duration(hours: 2)));
    return '$start – $end';
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.activity});
  final ActivityModel activity;

  /// Figma 43:203 — hero is exactly 240 tall.
  static const double _heroHeight = 240;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image
          activity.coverImageUrl != null
              ? Image.asset(
                  activity.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),

          // Figma 43:204 — a flat 40% black wash over the whole image, not a
          // gradient. Keeps the white status bar and controls legible on any
          // photo.
          const ColoredBox(color: AppColors.scrim),

          // Buttons — pinned to the top edge. `Stack`'s `StackFit.expand`
          // stretches every non-positioned child to fill the full 240 hero,
          // which was vertically centering this row instead of anchoring it
          // to the top. `Positioned` opts it out of that stretch.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x6,
                  vertical: AppSpacing.x1,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroBtn(
                      assetPath:
                          'assets/images/discovery/icons/arrow_left.svg',
                      onTap: () => Navigator.of(context).maybePop(),
                      label: 'Back',
                    ),
                    _HeroBtn(
                      assetPath: 'assets/images/discovery/icons/share.svg',
                      onTap: () {},
                      label: 'Share',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
    ),
    child: Center(
      // Held back to 38% so the placeholder reads as absent artwork
      // rather than as a deliberate icon.
      child: Icon(
        Icons.sports,
        size: 64,
        color: AppColors.textOnPrimary.withValues(alpha: 0.38),
      ),
    ),
  );
}

class _HeroBtn extends StatelessWidget {
  const _HeroBtn({
    required this.assetPath,
    required this.onTap,
    required this.label,
  });
  final String assetPath;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Visual sized down from Figma's 40×40 (43:215) to 36×36 — 40 read
        // heavy against the 240 hero. Hit area still padded to the 44pt
        // minimum tap target so it stays easy to press.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.scrimControl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SvgPicture.asset(
                assetPath,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.textOnPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.sport});
  final String sport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      // Figma 43:223 sets this text to #0f172a, but every other screen
      // (e.g. 74:31) uses primaryDarker and the exported mock renders blue.
      // Following the majority for consistency.
      child: Text(sport.toUpperCase(), style: AppTypography.badgeSport),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        // Figma 57:6 — radius 20, not the 28 used for modals.
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/discovery/icons/zap.svg',
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryDarker,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          Text(level.toUpperCase(), style: AppTypography.chipLabel),
        ],
      ),
    );
  }
}

class _HostRow extends StatelessWidget {
  const _HostRow({required this.hostName});
  final String hostName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          assetPath: 'assets/images/discovery/avatars/avatar_alex.png',
          name: hostName,
          size: AppAvatarSize.sm,
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hostName,
                style: AppTypography.bodyFormSecondary.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('Host', style: AppTypography.metaSub),
            ],
          ),
        ),
        SvgPicture.asset(
          'assets/images/discovery/icons/star.svg',
          width: 14,
          height: 14,
          colorFilter: const ColorFilter.mode(
            AppColors.warning,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '4.9',
          style: AppTypography.countAccent.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Overlapping participant avatars with a `+N` overflow badge.
///
/// Figma 43:253 draws five avatars plus a `+2` badge — seven people — while the
/// label beside it reads "6 joined / 10 total". That is an off-by-one in the
/// mock, so the count is derived from data here instead: up to
/// [_maxVisible] faces, then `+N` for the remainder. Always self-consistent.
class _ParticipantAvatars extends StatelessWidget {
  const _ParticipantAvatars({required this.count});

  final int count;

  /// Figma sizing: 32pt circles stepping 22pt apart (10pt overlap).
  static const double _size = 32;
  static const double _step = 22;
  static const int _maxVisible = 4;

  static const _faces = [
    'assets/images/discovery/avatars/avatar_1.png',
    'assets/images/discovery/avatars/avatar_2.png',
    'assets/images/discovery/avatars/avatar_3.png',
    'assets/images/discovery/avatars/avatar_alex.png',
  ];

  @override
  Widget build(BuildContext context) {
    final visible = count.clamp(0, _maxVisible);
    final overflow = count - visible;
    final slots = visible + (overflow > 0 ? 1 : 0);

    if (slots == 0) {
      return Text('No one has joined yet', style: AppTypography.metaSub);
    }

    return SizedBox(
      height: _size,
      width: _step * (slots - 1) + _size,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * _step,
              child: _Ring(
                child: Image.asset(
                  _faces[i % _faces.length],
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.avatarNeutral),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible * _step,
              child: _Ring(
                child: ColoredBox(
                  color: AppColors.border,
                  child: Center(
                    child: Text(
                      '+$overflow',
                      style: AppTypography.badgeSport.copyWith(
                        color: AppColors.textSecondary,
                      ),
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

/// 32pt circle with the white separator ring Figma uses on stacked avatars.
class _Ring extends StatelessWidget {
  const _Ring({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ParticipantAvatars._size,
      height: _ParticipantAvatars._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: ClipOval(child: child),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.title, required this.sub});
  final String icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Figma 43:235 — 34×34 and fully round (radius 100), not a rounded square.
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/images/discovery/icons/$icon',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryDarker,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.labelField),
              Text(sub, style: AppTypography.metaSub),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTypography.labelField)),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        child,
      ],
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/report/activity/$activityId'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          // Figma 62:9 — radius 12.
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/discovery/icons/alert_circle.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColors.danger,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            // Figma 62:11 fills this text white on an #f8fafc surface —
            // unreadable. Using danger, which the flag icon already implies.
            Text(
              'Report Activity',
              style: AppTypography.labelField.copyWith(color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.activity,
    required this.joining,
    required this.onDislike,
    required this.onJoin,
  });
  final ActivityModel activity;
  final bool joining;
  final VoidCallback onDislike;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x4,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        // Separates the pinned action bar from whatever's scrolled beneath
        // it — without this the buttons look like they're floating loose on
        // top of the content instead of anchored to the screen.
        boxShadow: AppShadows.bottomBar,
      ),
      // Figma 58:2 / 58:4 — the two buttons are deliberately different sizes:
      // dismiss is 56, join is 64. Visual weight signals which action matters.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: 'Not interested',
            child: GestureDetector(
              onTap: onDislike,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close_rounded,
                  size: 26,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x5),
          Semantics(
            button: true,
            label: activity.isFull ? 'Join waiting list' : 'Join activity',
            child: GestureDetector(
              onTap: activity.isFull ? null : onJoin,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: activity.isFull ? AppColors.border : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: activity.isFull ? null : AppShadows.glowPrimary,
                ),
                alignment: Alignment.center,
                child: joining
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnPrimary,
                          ),
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(
                        Icons.favorite_rounded,
                        size: 26,
                        color: AppColors.textOnPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
