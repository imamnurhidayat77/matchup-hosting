import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/nav_guard.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';
import '../../activities/domain/activity_participant.dart';
import '../../activities/presentation/my_activities_screen.dart';
import '../../report/presentation/report_activity_sheet.dart';
import 'widgets/venue_map_card.dart';

/// Back navigation that always lands somewhere. This screen is usually
/// reached via `context.go` (deck tap, deep link), which replaces the
/// route stack — a bare `maybePop()` then silently does nothing and the
/// back button feels dead. Fall back to Discover in that case.
void _popOrDiscovery(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/discovery');
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final _activityDetailProvider = FutureProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
      return ref.watch(activityRepositoryProvider).byId(id);
    });

/// Live roster for the avatar stack. Rendered faces always come from
/// this provider — never from bundled stock photos.
final _rosterProvider = FutureProvider.autoDispose
    .family<List<ActivityParticipant>, String>((ref, activityId) {
      return ref.watch(activityRepositoryProvider).participants(activityId);
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
      error: (e, _) => AppScaffold(
        body: ErrorRetry(
          message: 'Could not load activity details.',
          onRetry: () => ref.invalidate(_activityDetailProvider(activityId)),
        ),
      ),
      data: (activity) {
        if (activity == null) {
          return AppScaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Activity not found.'),
                    const SizedBox(height: AppSpacing.x4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PressableScale(
                          onTap: () => _popOrDiscovery(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x5,
                              vertical: AppSpacing.x3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: context.colors.border,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Back',
                              style: AppTypography.buttonPrimary.copyWith(
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        PressableScale(
                          onTap: () => ref.invalidate(
                            _activityDetailProvider(activityId),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x5,
                              vertical: AppSpacing.x3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              boxShadow: AppShadows.glowPrimary,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Retry',
                              style: AppTypography.buttonPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    return AppScaffold(
      safeAreaTop: false,
      body: Column(
        children: [
          const SkeletonBox(width: double.infinity, height: 280, radius: 0),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: double.infinity, height: 32, radius: 6),
                SizedBox(height: AppSpacing.x2),
                SkeletonBox(width: 200, height: 24, radius: 6),
                SizedBox(height: AppSpacing.x5),
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

  /// Tracks a just-sent join request locally so the button flips to
  /// "pending" immediately. Initialised from the backend viewer context
  /// (`joinRequestStatus`) for requests sent on another device/session.
  bool _requestPending = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasMoreBelow = true;

  @override
  void initState() {
    super.initState();
    _requestPending = widget.activity.hasPendingRequest;
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
    final atBottom = position.pixels >= position.maxScrollExtent - 4;
    if (atBottom == _hasMoreBelow) {
      setState(() => _hasMoreBelow = !atBottom);
    }
  }

  Future<void> _onJoin() async {
    HapticFeedback.mediumImpact();
    setState(() => _joining = true);
    try {
      // Approval-gated activities file a join request instead of
      // joining outright; withdrawing a pending request goes through
      // leave (the backend cancels it server-side).
      if (widget.activity.requiresApproval && !_requestPending) {
        await ref.read(activityRepositoryProvider).requestJoin(widget.activityId);
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() => _requestPending = true);
        // Refresh the detail (viewer context now carries the pending
        // request) so a remount renders the pending pill from data.
        ref.invalidate(_activityDetailProvider(widget.activityId));
        // And the Pending tab, which caches keepAlive-side.
        ref.invalidate(pendingGamesProvider);
        AppSnackbar.show(
          context,
          message: 'Request sent! The host will review it soon.',
          variant: AppSnackbarVariant.success,
        );
        return;
      }
      await ref.read(activityRepositoryProvider).join(widget.activityId);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Upcoming caches keepAlive-side — refresh it now so the game is
      // there when the user opens My Games.
      ref.invalidate(joinedGamesProvider);
      AppSnackbar.show(
        context,
        message: 'You\'ve joined ${widget.activity.title}!',
        variant: AppSnackbarVariant.success,
      );
      // The joined activity rides along as route extra for any
      // downstream screen that accepts cached fallback content.
      context.go(
        '/joined-activity/${widget.activityId}',
        extra: widget.activity,
      );
    } catch (e) {
      if (!mounted) return;
      // Surface precise backend rejections ("Activity is full",
      // "Activity has already started") instead of a generic failure.
      final message = e is DioException && e.error is ApiException
          ? (e.error as ApiException).userMessage
          : (widget.activity.requiresApproval && !_requestPending
              ? 'Could not send request. Please try again.'
              : 'Could not join. Please try again.');
      AppSnackbar.show(
        context,
        message: message,
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;

    // Overlap amount: card naik sejauh ini ke dalam hero.
    // Pills ada di bottom: x4 (~16px) hero, tinggi pill ~32px → pills
    // berakhir di heroHeight - 16. Card overlap 20px: card top = heroHeight - 20.
    // Pills dengan bottom:16 berarti top = heroHeight - 16 - 32 ≈ heroHeight - 48.
    // Jadi pills tetap di atas card (heroHeight-48 < heroHeight-20). ✓
    const double overlapAmount = 44;
    const double heroH = _Hero.heroHeight;

    return AppScaffold(
      safeAreaTop: false,
      bottomBar: _ActionBar(
        activity: widget.activity,
        joining: _joining,
        requestPending: _requestPending,
        onDislike: () => _popOrDiscovery(context),
        onJoin: _onJoin,
      ),
      body: Stack(
        children: [
          // ── Layer 1: hero (fixed height, full-width) ─────────────────
          SizedBox(
            height: heroH,
            width: double.infinity,
            child: _Hero(activity: a),
          ),

          // ── Layer 2: white card, starts heroH - overlap from top ─────
          // Positioned.fill + top leaves the card filling everything from
          // that top offset to the bottom of the body.
          Positioned(
            top: heroH - overlapAmount,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: _hasMoreBelow
                    ? const [AppColors.scrimTransparent, AppColors.textPrimary]
                    : const [AppColors.textPrimary, AppColors.textPrimary],
                stops: const [0.0, 0.06],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  boxShadow: AppShadows.sheet,
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  // Extra top padding compensates for the overlap so content
                  // starts below where the pills hang over.
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x5,
                    AppSpacing.x5,
                    AppSpacing.x5,
                    AppSpacing.x8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: AppTypography.headingDisplay(context),
                      ),
                      const SizedBox(height: AppSpacing.x5),
                      _HostCard(
                        hostName: a.hostName,
                        hostId: a.hostId,
                        hostRating: a.hostRating,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _MetaCard(activity: a),
                      const SizedBox(height: AppSpacing.x5),
                      // Venue map only when the activity carries
                      // coordinates — older rows may not have them.
                      if (a.latitude != null && a.longitude != null) ...[
                        VenueMapCard(activity: a),
                        const SizedBox(height: AppSpacing.x5),
                      ],
                      Text(
                        'About this Activity',
                        style: AppTypography.titleMedium(context),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Text(
                        a.description,
                        style: AppTypography.bodyReading(context),
                      ),
                      const SizedBox(height: AppSpacing.x5),
                      _ParticipantsSection(activity: a),
                      const SizedBox(height: AppSpacing.x5),
                      _ReportButton(activity: widget.activity),
                    ],
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

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.activity});
  final ActivityModel activity;

  static const double heroHeight = 280;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image (bundled asset or remote Storage URL)
          activity.coverImageUrl != null
              ? AssetImageWithFallback(
                  imagePath: activity.coverImageUrl!,
                  fit: BoxFit.cover,
                )
              : _placeholder(),

          // Subtle gradient scrim — darkens from bottom so badges stay legible
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.scrimTransparent, AppColors.scrimGradient],
                stops: [0.45, 1.0],
              ),
            ),
          ),

          // Back + Share buttons pinned to top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x5,
                  vertical: AppSpacing.x2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroBtn(
                      icon: AppIcons.arrowLeft,
                      onTap: () => _popOrDiscovery(context),
                      label: 'Back',
                    ),
                    _HeroBtn(
                      icon: AppIcons.share,
                      onTap: () => ShareHelper.shareActivity(activity),
                      label: 'Share',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pills — bottom, selalu di atas card (z-order terakhir dalam Stack).
          // Wrap (not Row) so long sport/skill labels fold instead of
          // overflowing on narrow screens.
          Positioned(
            left: AppSpacing.x5,
            bottom: AppSpacing.x4 + 20 + 20,
            child: Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                _SportBadgeHero(sport: activity.sportType),
                _SkillBadgeHero(level: activity.skillLevel),
              ],
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
    required this.icon,
    required this.onTap,
    required this.label,
  });
  final String icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.scrimControl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: AppIcon(
                icon,
                size: AppIconSize.lg,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill badge for sport type — shown over hero image.
class _SportBadgeHero extends StatelessWidget {
  const _SportBadgeHero({required this.sport});
  final String sport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        sport.toUpperCase(),
        style: AppTypography.chipLabel(context).copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Blue filled pill badge for skill level — shown over hero image.
class _SkillBadgeHero extends StatelessWidget {
  const _SkillBadgeHero({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on_rounded, size: 13, color: AppColors.textOnPrimary),
          const SizedBox(width: 4),
          Text(
            level.toUpperCase(),
            style: AppTypography.chipLabel(context).copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Host card ────────────────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.hostName,
    required this.hostId,
    required this.hostRating,
  });
  final String hostName;
  final String hostId;
  final double hostRating;

  @override
  Widget build(BuildContext context) {
    final canOpen = hostId.trim().isNotEmpty;
    return Semantics(
      button: canOpen,
      label: canOpen ? 'View host profile: $hostName' : null,
      child: PressableScale(
        // Double-tap guard: a second push before the first registers
        // creates two pages with the same key and red-screens
        // ('!keyReservation.contains(key)'). See NavGuard.
        onTap: canOpen
            ? () => NavGuard.onceFor(
                  'host-profile-$hostId',
                  () => context.push('/player-profile/uid/${hostId.trim()}'),
                )
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              AppAvatar(
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
                      style: AppTypography.labelField(context).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('Host', style: AppTypography.metaSub(context)),
                  ],
                ),
              ),
              // Rating badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: context.colors.successText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hostRating.toStringAsFixed(1),
                    style: AppTypography.labelField(context).copyWith(
                      color: context.colors.successText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (canOpen) ...[
                const SizedBox(width: AppSpacing.x1),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.colors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Meta card (date + location) ─────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d').format(activity.dateTime);
    final startTime = DateFormat('h:mm a').format(activity.dateTime);
    final endTime = DateFormat('h:mm a').format(activity.endTime);
    final timeRange = '$startTime - $endTime';
    final address =
        activity.addressLine ?? distanceLabel(activity.distanceKm) ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _MetaRow(
            icon: AppIcons.calendar,
            title: date,
            sub: timeRange,
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _MetaRow(
            icon: AppIcons.mapPin,
            title: activity.location,
            sub: address,
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _MetaRow(
            icon: AppIcons.dollarSign,
            title: !activity.isPaid
                ? 'Free Activity'
                : activity.isSplitCost
                    ? 'Split Cost'
                    : 'Paid Activity',
            sub: !activity.isPaid
                ? 'No cost to join'
                : activity.splitExplainer ??
                    activity.feeLabel ??
                    'Fee required to join',
            trailingChip: _FeeChip(isPaid: activity.isPaid),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.trailingChip,
  });
  final String icon;
  final String title;
  final String sub;
  final Widget? trailingChip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(
              icon,
              size: AppIconSize.lg,
              color: context.colors.primaryOnSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelField(context)),
                // The sub-row (address / distance) hides entirely when
                // empty so no blank line sits under the title.
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: AppTypography.metaSub(context)),
                ],
              ],
            ),
          ),
          if (trailingChip != null) ...[
            const SizedBox(width: AppSpacing.x2),
            trailingChip!,
          ],
        ],
      ),
    );
  }
}

class _FeeChip extends StatelessWidget {
  const _FeeChip({required this.isPaid});
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final bgColor = isPaid
        ? context.colors.warningBg
        : context.colors.statusSuccessBg;
    final fgColor = isPaid
        ? context.colors.warningText
        : context.colors.successText;
    final label = isPaid ? 'Paid' : 'Free';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel(context).copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Participants section ─────────────────────────────────────────────────────

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final waiting = activity.requiresApproval ? activity.pendingRequestCount : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Participants',
                style: AppTypography.titleMedium(context),
              ),
            ),
            Text(
              '${activity.participantCount} joined / ${activity.capacity} total',
              style: AppTypography.countAccent(context),
            ),
          ],
        ),
        if (waiting > 0) ...[
          const SizedBox(height: 2),
          Text(
            '$waiting waiting for approval',
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colors.warningText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x3),
        _ParticipantAvatars(activityId: activity.id),
      ],
    );
  }
}

/// Overlapping participant avatars with a `+N` overflow badge.
///
/// Faces come from the live roster (`activityRepository.participants`):
/// backend photo when the user has one, initials otherwise. While the
/// roster loads or fails, nothing fake is shown.
class _ParticipantAvatars extends ConsumerWidget {
  const _ParticipantAvatars({required this.activityId});
  final String activityId;

  static const double _size = 32;
  static const double _step = 22;
  static const int _maxVisible = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(_rosterProvider(activityId));

    return roster.when(
      loading: () => const SkeletonBox(width: 160, height: 32, radius: 16),
      error: (_, _) => ErrorRetry(
        message: 'Could not load participants.',
        onRetry: () => ref.invalidate(_rosterProvider(activityId)),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            'No one has joined yet',
            style: AppTypography.metaSub(context),
          );
        }
        final visible = members.take(_maxVisible).toList();
        final overflow = members.length - visible.length;
        return _AvatarStack(
          members: visible,
          overflow: overflow,
        );
      },
    );
  }
}

/// Overlapping avatar row shared by the roster-backed stacks.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members, required this.overflow});
  final List<ActivityParticipant> members;
  final int overflow;

  @override
  Widget build(BuildContext context) {
    final slots = members.length + (overflow > 0 ? 1 : 0);

    return SizedBox(
      height: _ParticipantAvatars._size,
      width: _ParticipantAvatars._step * (slots - 1) +
          _ParticipantAvatars._size,
      child: Stack(
        children: [
          for (var i = 0; i < members.length; i++)
            Positioned(
              left: i * _ParticipantAvatars._step,
              child: _Ring(
                child: AppAvatar(
                  imageUrl: members[i].avatarUrl,
                  name: members[i].name,
                  size: AppAvatarSize.sm,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: members.length * _ParticipantAvatars._step,
              child: _Ring(
                child: ColoredBox(
                  color: context.colors.border,
                  child: Center(
                    child: Text(
                      '+$overflow',
                      style: AppTypography.badgeSport(
                        context,
                      ).copyWith(color: context.colors.textSecondary),
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
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      child: ClipOval(child: child),
    );
  }
}

// ─── Report button ────────────────────────────────────────────────────────────

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => ReportActivitySheet.show(
        context,
        activityId: activity.id,
        activityTitle: activity.title,
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.alertCircle,
              size: AppIconSize.lg,
              color: context.colors.errorText,
            ),
            const SizedBox(width: 8),
            Text(
              'Report Activity',
              style: AppTypography.labelField(
                context,
              ).copyWith(color: context.colors.errorText),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.activity,
    required this.joining,
    required this.requestPending,
    required this.onDislike,
    required this.onJoin,
  });
  final ActivityModel activity;
  final bool joining;

  /// A sent-but-undecided join request. Renders a disabled pill so the
  /// user knows the host still has to act.
  final bool requestPending;
  final VoidCallback onDislike;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final canJoin =
        !activity.isFull && !requestPending && !activity.hasStarted && !joining;
    final joinLabel = requestPending
        ? 'Request pending'
        : activity.hasStarted
            ? 'Already started'
            : activity.requiresApproval
                ? 'Request to Join'
                : (canJoin ? 'Join Game' : 'Activity Full');

    // Why the pill is disabled — surfaced on tap instead of a dead tap.
    String? disabledReason() {
      if (requestPending) return 'Your request is pending host approval.';
      if (activity.hasStarted) return 'This activity has already started.';
      if (activity.isFull) return 'This activity is full.';
      return null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: Row(
        children: [
          // Small dismiss circle button on the left
          Semantics(
            button: true,
            label: 'Not interested',
            child: PressableScale(
              onTap: onDislike,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Full-width Join Game pill button
          Expanded(
            child: Semantics(
              button: true,
              label: requestPending
                  ? 'Join request pending'
                  : (activity.hasStarted
                      ? 'Activity already started'
                      : (canJoin ? 'Join Game' : 'Activity is full')),
              child: PressableScale(
                // Disabled pills still explain themselves on tap
                // (full / started / pending) — except mid-submit, when
                // the spinner is showing and taps stay ignored.
                onTap: canJoin
                    ? onJoin
                    : (joining
                        ? null
                        : () {
                            final reason = disabledReason();
                            if (reason == null) return;
                            AppSnackbar.show(
                              context,
                              message: reason,
                              variant: AppSnackbarVariant.info,
                            );
                          }),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: canJoin
                        ? AppColors.primary
                        : context.colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: canJoin ? AppShadows.glowPrimary : null,
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
                      : Text(
                          joinLabel,
                          style: AppTypography.buttonPrimary.copyWith(
                            color: AppColors.textOnPrimary,
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
