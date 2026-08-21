import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../chat/domain/chat_message.dart';
import '../../discovery/domain/activity_model.dart';

// ─── Data type ───────────────────────────────────────────────────────────────

typedef _DetailData = ({
  ActivityModel activity,
  List<ChatMessage> recentMessages,
});

final _detailProvider = FutureProvider.autoDispose
    .family<_DetailData, String>((ref, activityId) async {
  final activity = await ref.watch(activityRepositoryProvider).byId(activityId);
  if (activity == null) throw StateError('Activity not found');
  final messages = await ref.watch(chatRepositoryProvider).messages(activityId);
  final recent =
      messages.length > 2 ? messages.sublist(messages.length - 2) : messages;
  return (activity: activity, recentMessages: recent);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class JoinedActivityDetailScreen extends ConsumerWidget {
  const JoinedActivityDetailScreen({super.key, required this.activityId});
  final String activityId;

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Leave Activity?'),
        content: const Text(
          'Are you sure you want to leave? You can re-join later if spots are available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'You have left the activity.',
      variant: AppSnackbarVariant.info,
    );
    if (context.mounted) context.go('/activities');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_detailProvider(activityId));

    return AppScaffold(
      safeAreaTop: false,
      backgroundColor: context.colors.background,
      showHomeIndicator: false,
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () => ref.invalidate(_detailProvider(activityId)),
        ),
        data: (data) => _DetailBody(
          activity: data.activity,
          recentMessages: data.recentMessages,
          onLeave: () => _confirmLeave(context),
        ),
      ),
    );
  }
}

// ─── Detail body ─────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.activity,
    required this.recentMessages,
    required this.onLeave,
  });

  final ActivityModel activity;
  final List<ChatMessage> recentMessages;
  final VoidCallback onLeave;

  // Must match activity_detail_screen hero height for visual consistency.
  static const double _heroHeight = 280;
  static const double _overlapAmount = 44;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Hero ─────────────────────────────────────────────────────────
        SizedBox(
          height: _heroHeight,
          width: double.infinity,
          child: _Hero(activity: activity),
        ),

        // ── Scrollable card ───────────────────────────────────────────────
        Positioned(
          top: _heroHeight - _overlapAmount,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              boxShadow: AppShadows.sheet,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x5,
                AppSpacing.x5,
                AppSpacing.x8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activity.title,
                    style: AppTypography.headingDisplay(context),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // You're in banner
                  _JoinedBanner(dateTime: activity.dateTime),
                  const SizedBox(height: AppSpacing.x4),

                  // Host card
                  _HostCard(
                    hostName: activity.hostName,
                    hostRating: activity.hostRating,
                  ),
                  const SizedBox(height: AppSpacing.x3),

                  // Meta card — date + location
                  _MetaCard(activity: activity),
                  const SizedBox(height: AppSpacing.x5),

                  // Participants
                  _ParticipantsSection(activity: activity),
                  const SizedBox(height: AppSpacing.x5),

                  // Group chat preview
                  _ChatSection(
                    messages: recentMessages,
                    activityTitle: activity.title,
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // Actions
                  _AddToCalendarButton(activity: activity),
                  const SizedBox(height: AppSpacing.x3),
                  _CheckInButton(activityId: activity.id),
                  const SizedBox(height: AppSpacing.x4),

                  // Leave
                  Center(
                    child: PressableScale(
                      onTap: onLeave,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x2),
                        child: Text(
                          'Leave Activity',
                          style: AppTypography.labelField(
                            context,
                          ).copyWith(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Stack(
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

        // Bottom gradient scrim
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

        // Back button — top-left
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
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                    label: 'Back',
                  ),
                  _HeroBtn(
                    icon: Icons.ios_share_rounded,
                    onTap: () {},
                    label: 'Share',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sport + JOINED badges — bottom-left
        Positioned(
          left: AppSpacing.x5,
          bottom: AppSpacing.x4 + 40,
          child: Row(
            children: [
              _PillBadge(
                label: activity.sportType.toUpperCase(),
                bgColor: AppColors.textOnPrimary,
                textColor: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.x2),
              _PillBadge(
                label: '✓  JOINED',
                bgColor: AppColors.avatarSecondary,
                textColor: AppColors.textOnPrimary,
              ),
            ],
          ),
        ),
      ],
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
  final IconData icon;
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
                color: AppColors.scrimControl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 18, color: AppColors.textOnPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel(context).copyWith(
          color: textColor,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─── Joined banner ────────────────────────────────────────────────────────────

class _JoinedBanner extends StatelessWidget {
  const _JoinedBanner({required this.dateTime});
  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEE, MMM d 'at' h:mm a");
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.avatarSecondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: AppColors.avatarSecondary,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're in!",
                  style: AppTypography.labelField(context).copyWith(
                    color: AppColors.avatarSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'See you on ${fmt.format(dateTime)}',
                  style: AppTypography.metaSub(context).copyWith(
                    color: AppColors.avatarSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Host card (matches activity_detail_screen._HostCard) ─────────────────────

class _HostCard extends StatelessWidget {
  const _HostCard({required this.hostName, required this.hostRating});
  final String hostName;
  final double hostRating;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/player-profile/$hostName'),
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
                    style: AppTypography.labelField(context).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('Host', style: AppTypography.metaSub(context)),
                ],
              ),
            ),
            // Message button
            AppTappable(
              semanticLabel: 'Message host',
              feedback: AppTapFeedback.scale,
              minSize: 36,
              onTap: () => context.push('/chat/$hostName'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.message_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            // Rating
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  hostRating.toStringAsFixed(1),
                  style: AppTypography.labelField(context).copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meta card (date + location) — matches activity_detail_screen ─────────────

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d').format(activity.dateTime);
    final start = DateFormat('h:mm a').format(activity.dateTime);
    final end = DateFormat('h:mm a').format(activity.endTime);
    final address =
        activity.addressLine ??
        '${activity.distanceKm.toStringAsFixed(1)} km away';

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
            icon: Icons.calendar_month_outlined,
            title: date,
            sub: '$start – $end',
          ),
          Divider(height: 1, color: context.colors.border, indent: 60),
          _MetaRow(
            icon: Icons.place_outlined,
            title: activity.location,
            sub: address,
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
  });
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: context.colors.primaryOnSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelField(context)),
                const SizedBox(height: 2),
                Text(sub, style: AppTypography.metaSub(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Participants section ─────────────────────────────────────────────────────

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({required this.activity});
  final ActivityModel activity;

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
    final count = activity.participantCount;
    final visible = count.clamp(0, _maxVisible);
    final overflow = count - visible;
    final slots = visible + (overflow > 0 ? 1 : 0);

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
              '$count joined / ${activity.capacity} total',
              style: AppTypography.countAccent(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        if (slots == 0)
          Text('No one has joined yet.', style: AppTypography.metaSub(context))
        else
          SizedBox(
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
                            ColoredBox(color: context.colors.avatarNeutral),
                      ),
                    ),
                  ),
                if (overflow > 0)
                  Positioned(
                    left: visible * _step,
                    child: _Ring(
                      child: ColoredBox(
                        color: context.colors.border,
                        child: Center(
                          child: Text(
                            '+$overflow',
                            style: AppTypography.badgeSport(context).copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ParticipantsSection._size,
      height: _ParticipantsSection._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      child: ClipOval(child: child),
    );
  }
}

// ─── Chat section ─────────────────────────────────────────────────────────────

class _ChatSection extends StatelessWidget {
  const _ChatSection({
    required this.messages,
    required this.activityTitle,
  });
  final List<ChatMessage> messages;
  final String activityTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group Chat', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (final msg in messages) ...[
                _ChatMsgRow(message: msg),
                const SizedBox(height: AppSpacing.x3),
              ],
              // Open Chat button
              PressableScale(
                onTap: () => context.push('/chat/$activityTitle'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.x3,
                    horizontal: AppSpacing.x4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        'Open Group Chat',
                        style: AppTypography.labelField(context).copyWith(
                          color: AppColors.primary,
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
    );
  }
}

class _ChatMsgRow extends StatelessWidget {
  const _ChatMsgRow({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(message.sentAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          assetPath: message.senderAvatarAsset,
          name: message.senderName,
          size: AppAvatarSize.xs,
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.senderName,
                      style: AppTypography.chipLabel(context)
                          .copyWith(fontSize: 12),
                    ),
                  ),
                  Text(
                    time,
                    style: AppTypography.metaSub(context)
                        .copyWith(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                message.text,
                style: AppTypography.bodyReading(context).copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _AddToCalendarButton extends StatelessWidget {
  const _AddToCalendarButton({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () async {
        final ok = await CalendarService.instance.addEvent(
          title: activity.title,
          start: activity.dateTime,
          end: activity.endTime,
          description: 'MatchUp activity — check the app for details.',
          location: activity.location,
        );
        if (!context.mounted) return;
        AppSnackbar.show(
          context,
          message: ok ? 'Added to calendar' : 'Could not add to calendar',
          variant: ok ? AppSnackbarVariant.success : AppSnackbarVariant.error,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: context.colors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: context.colors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Add to Calendar',
              style: AppTypography.labelField(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/check-in/$activityId'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.glowPrimary,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.textOnPrimary,
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Check In',
              style: AppTypography.buttonPrimary.copyWith(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
