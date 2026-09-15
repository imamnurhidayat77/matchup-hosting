import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../chat/domain/chat_message.dart';
import '../../discovery/domain/activity_model.dart';
import '../../discovery/presentation/widgets/venue_map_card.dart';
import '../domain/activity_participant.dart';

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

/// Live roster for the participant avatar stack — real faces only.
final _rosterProvider = FutureProvider.autoDispose
    .family<List<ActivityParticipant>, String>((ref, activityId) {
  return ref.watch(activityRepositoryProvider).participants(activityId);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class JoinedActivityDetailScreen extends ConsumerWidget {
  const JoinedActivityDetailScreen({super.key, required this.activityId});
  final String activityId;

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Leave Activity?',
      body: 'Are you sure you want to leave? You can re-join later if spots are available.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(activityRepositoryProvider).leave(activityId);
      ref.invalidate(_detailProvider(activityId));
      ref.invalidate(activityFeedProvider);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'You have left the activity.',
        variant: AppSnackbarVariant.info,
      );
      if (context.mounted) context.go('/activities');
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not leave the activity. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
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
          onLeave: () => _confirmLeave(context, ref),
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

                  // Venue map (only when coordinates exist).
                  if (activity.latitude != null &&
                      activity.longitude != null) ...[
                    VenueMapCard(activity: activity),
                    const SizedBox(height: AppSpacing.x5),
                  ],

                  // Participants
                  _ParticipantsSection(activity: activity),
                  const SizedBox(height: AppSpacing.x5),

                  // Group chat preview
                  _ChatSection(
                    messages: recentMessages,
                    activityId: activity.id,
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
                          ).copyWith(color: context.colors.errorText),
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
        // Cover image (bundled asset or remote Storage URL)
        activity.coverImageUrl != null
            ? AssetImageWithFallback(
                imagePath: activity.coverImageUrl!,
                fit: BoxFit.cover,
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
                    onTap: () => ShareHelper.shareActivity(activity),
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
                  color: context.colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.message_rounded,
                  size: 16,
                  color: context.colors.primaryOnSurface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            // Rating
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
          Divider(height: 1, color: context.colors.border, indent: 60),
          _MetaRow(
            icon: Icons.attach_money_rounded,
            title: activity.isPaid ? 'Paid Activity' : 'Free Activity',
            sub: activity.isPaid ? 'Fee required to join' : 'No cost to join',
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
  final IconData icon;
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
    final bgColor =
        isPaid ? context.colors.warningBg : context.colors.statusSuccessBg;
    final fgColor =
        isPaid ? context.colors.warningText : context.colors.successText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Free',
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

class _ParticipantsSection extends ConsumerWidget {
  const _ParticipantsSection({required this.activity});
  final ActivityModel activity;

  static const double _size = 32;
  static const double _step = 22;
  static const int _maxVisible = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = activity.participantCount;
    final roster = ref.watch(_rosterProvider(activity.id));

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
        roster.when(
          loading: () => const SizedBox(height: _size),
          error: (_, _) => const SizedBox(height: _size),
          data: (members) {
            if (members.isEmpty) {
              return Text(
                'No one has joined yet.',
                style: AppTypography.metaSub(context),
              );
            }
            final visible = members.take(_maxVisible).toList();
            final overflow = members.length - visible.length;
            final slots = visible.length + (overflow > 0 ? 1 : 0);
            return SizedBox(
              // Keyed so tests can scope finders to the live roster
              // stack (the host card elsewhere shows the same
              // initials when host == organizer).
              key: const ValueKey('participant-stack'),
              height: _size,
              width: _step * (slots - 1) + _size,
              child: Stack(
                children: [
                  for (var i = 0; i < visible.length; i++)
                    Positioned(
                      left: i * _step,
                      child: _Ring(
                        child: AppAvatar(
                          imageUrl: visible[i].avatarUrl,
                          name: visible[i].name,
                          size: AppAvatarSize.sm,
                        ),
                      ),
                    ),
                  if (overflow > 0)
                    Positioned(
                      left: visible.length * _step,
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
            );
          },
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
    required this.activityId,
  });
  final List<ChatMessage> messages;
  final String activityId;

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
                onTap: () => context.push('/chat/$activityId'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.x3,
                    horizontal: AppSpacing.x4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: context.colors.primaryOnSurface
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 18,
                        color: context.colors.primaryOnSurface,
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        'Open Group Chat',
                        style: AppTypography.labelField(context).copyWith(
                          color: context.colors.primaryOnSurface,
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
                message.isImage ||
                        ChatMessage.imageUrlFromText(message.text) != null
                    ? '[photo]'
                    : message.text,
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
