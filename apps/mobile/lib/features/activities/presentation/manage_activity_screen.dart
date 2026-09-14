import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
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
import '../../../core/widgets/label_badge.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/activity_participant.dart';
import '../../discovery/domain/activity_model.dart';

// ─── Data type ───────────────────────────────────────────────────────────────

typedef _ManageData = ({
  ActivityModel activity,
  List<ActivityParticipant> roster,
  List<ActivityParticipant> requests,
});

final _manageProvider = FutureProvider.autoDispose
    .family<_ManageData, String>((ref, activityId) async {
  final repo = ref.watch(activityRepositoryProvider);
  final activity = await repo.byId(activityId);
  if (activity == null) throw StateError('Activity not found');
  // joinRequests is host-gated server-side; non-hosts (and offline)
  // get an empty list, so this is safe to always request.
  final (roster, requests) = await (
    repo.participants(activityId),
    repo.joinRequests(activityId),
  ).wait;
  return (activity: activity, roster: roster, requests: requests);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ManageActivityScreen extends ConsumerWidget {
  const ManageActivityScreen({super.key, required this.activityId});
  final String activityId;

  /// Opens the edit screen; refreshes the detail provider and confirms
  /// when the host saved changes (the edit screen pops `true`, silent,
  /// because its own snackbar would die with its route).
  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final updated =
        await context.push<bool>('/edit-activity/$activityId');
    if (updated != true || !context.mounted) return;
    ref.invalidate(_manageProvider(activityId));
    AppSnackbar.show(
      context,
      message: 'Activity updated.',
      variant: AppSnackbarVariant.success,
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cancel Activity?',
      body: 'This will permanently cancel the activity and notify all participants. This cannot be undone.',
      confirmLabel: 'Cancel Activity',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await ref.read(activityRepositoryProvider).cancel(activityId);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Activity cancelled. Participants have been notified.',
        variant: AppSnackbarVariant.info,
      );
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not cancel activity. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _decideRequest(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String name, {
    required bool approve,
  }) async {
    try {
      final repo = ref.read(activityRepositoryProvider);
      if (approve) {
        await repo.approveJoinRequest(activityId, uid);
      } else {
        await repo.declineJoinRequest(activityId, uid);
      }
      ref.invalidate(_manageProvider(activityId));
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: approve
            ? '$name approved! They have been notified.'
            : '$name declined.',
        variant: approve ? AppSnackbarVariant.success : AppSnackbarVariant.info,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: approve
            ? 'Could not approve. The activity may be full.'
            : 'Could not decline. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _confirmComplete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Mark as Completed?',
      body: 'This closes the activity so no one else can join. You can still see it in your history.',
      confirmLabel: 'Mark Completed',
      cancelLabel: 'Not yet',
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(activityRepositoryProvider)
          .updateStatus(activityId, 'completed');
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Activity marked as completed.',
        variant: AppSnackbarVariant.success,
      );
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not update activity. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_manageProvider(activityId));

    return AppScaffold(
      safeAreaTop: false,
      backgroundColor: context.colors.background,
      showHomeIndicator: false,
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () => ref.invalidate(_manageProvider(activityId)),
        ),
        data: (data) => _ManageBody(
          activityId: activityId,
          activity: data.activity,
          roster: data.roster,
          requests: data.requests,
          onEdit: () => _openEdit(context, ref),
          onCancel: () => _confirmCancel(context, ref),
          onComplete: () => _confirmComplete(context, ref),
          onApprove: (uid, name) =>
              _decideRequest(context, ref, uid, name, approve: true),
          onDecline: (uid, name) =>
              _decideRequest(context, ref, uid, name, approve: false),
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ManageBody extends StatelessWidget {
  const _ManageBody({
    required this.activityId,
    required this.activity,
    required this.roster,
    required this.requests,
    required this.onEdit,
    required this.onCancel,
    required this.onComplete,
    required this.onApprove,
    required this.onDecline,
  });

  final String activityId;
  final ActivityModel activity;
  final List<ActivityParticipant> roster;

  /// Pending join requests (approval-gated activities only, host view).
  final List<ActivityParticipant> requests;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  /// `onApprove(uid, displayName)` / `onDecline(uid, displayName)`.
  final void Function(String uid, String name) onApprove;
  final void Function(String uid, String name) onDecline;

  static const double _heroHeight = 280;
  static const double _overlapAmount = 44;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Hero ────────────────────────────────────────────────────────
        SizedBox(
          height: _heroHeight,
          width: double.infinity,
          child: _Hero(
            activity: activity,
            onEdit: onEdit,
          ),
        ),

        // ── White card ──────────────────────────────────────────────────
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
                  // Title + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: AppTypography.headingDisplay(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      LabelBadge(
                        label: activity.status == ActivityStatus.past
                            ? 'CANCELLED'
                            : 'ACTIVE',
                        background: activity.status == ActivityStatus.past
                            ? context.colors.errorLight
                            : context.colors.statusSuccessBg,
                        foreground: activity.status == ActivityStatus.past
                            ? context.colors.errorText
                            : AppColors.avatarSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Capacity progress card
                  _CapacityCard(activity: activity, joined: roster.length),
                  const SizedBox(height: AppSpacing.x3),

                  // Meta card — date + location
                  _MetaCard(activity: activity),
                  const SizedBox(height: AppSpacing.x5),

                  // Quick actions
                  _QuickActions(
                    activityId: activityId,
                    activity: activity,
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // Participants
                  _ParticipantsSection(
                    activityId: activityId,
                    roster: roster,
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // Pending join requests (approval policy only)
                  if (requests.isNotEmpty) ...[
                    _JoinRequestsSection(
                      requests: requests,
                      onApprove: (p) => onApprove(p.userId, p.name),
                      onDecline: (p) => onDecline(p.userId, p.name),
                    ),
                    const SizedBox(height: AppSpacing.x5),
                  ],

                  // Activity details
                  _DetailsSection(activity: activity),
                  const SizedBox(height: AppSpacing.x5),

                  // Mark as completed — only available once the activity
                  // time has passed. Host-only; the backend rejects the
                  // status update from non-hosts with FORBIDDEN.
                  if (activity.dateTime.isBefore(DateTime.now())) ...[
                    _CompleteButton(onTap: onComplete),
                    const SizedBox(height: AppSpacing.x3),
                  ],

                  // Cancel
                  _CancelButton(onTap: onCancel),
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
  const _Hero({required this.activity, required this.onEdit});
  final ActivityModel activity;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        activity.coverImageUrl != null
            ? AssetImageWithFallback(
                imagePath: activity.coverImageUrl!,
                fit: BoxFit.cover,
              )
            : _placeholder(),

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

        // Back + edit buttons
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
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                    label: 'Edit activity',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sport + HOST badges
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
                label: '👑  HOST',
                bgColor: context.colors.warningBg,
                textColor: context.colors.warningText,
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

// ─── Capacity card ────────────────────────────────────────────────────────────

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.activity, required this.joined});
  final ActivityModel activity;
  final int joined;

  @override
  Widget build(BuildContext context) {
    final ratio = activity.capacity == 0
        ? 0.0
        : (joined / activity.capacity).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 18, color: context.colors.primaryOnSurface),
                  const SizedBox(width: 6),
                  Text(
                    '$joined joined',
                    style: AppTypography.labelField(context),
                  ),
                ],
              ),
              Text(
                '${activity.capacity} total',
                style: AppTypography.metaSub(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          ClipRRect(
            borderRadius: AppRadius.pillR,
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: context.colors.surfaceMuted),
                  FractionallySizedBox(
                    widthFactor: ratio,
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

// ─── Meta card (date + location) ─────────────────────────────────────────────

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
            child: Icon(icon, size: 18,
                color: context.colors.primaryOnSurface),
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

// ─── Quick actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.activityId, required this.activity});
  final String activityId;
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                iconColor: context.colors.primaryOnSurface,
                bgColor: context.colors.primarySoft,
                onTap: () => _showEditSheet(context),
              ),
            ),
            Expanded(
              child: _ActionBtn(
                icon: Icons.share_outlined,
                label: 'Share',
                iconColor: context.colors.textPrimary,
                bgColor: context.colors.surfaceMuted,
                onTap: () => _showShareSheet(context),
              ),
            ),
            Expanded(
              child: _ActionBtn(
                icon: Icons.campaign_outlined,
                label: 'Announce',
                iconColor: context.colors.warningText,
                bgColor: context.colors.warningBg,
                onTap: () => _showAnnounceSheet(context),
              ),
            ),
            Expanded(
              child: _ActionBtn(
                icon: Icons.people_outline_rounded,
                label: 'Roster',
                iconColor: context.colors.textPrimary,
                bgColor: context.colors.surfaceMuted,
                onTap: () => context.push('/activity/$activityId/participants'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(activityId: activityId, activity: activity),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(activity: activity),
    );
  }

  void _showAnnounceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnnounceSheet(activityId: activityId),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: label,
      feedback: AppTapFeedback.scale,
      minSize: 0,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            label,
            style: AppTypography.caption(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Edit sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.activityId, required this.activity});
  final String activityId;
  final ActivityModel activity;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.activity.title);
    _locationCtrl = TextEditingController(text: widget.activity.location);
    _descCtrl = TextEditingController(text: widget.activity.description);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final description = _descCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Please enter a title.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(activityRepositoryProvider).updateActivity(
            activityId: widget.activityId,
            title: title,
            locationName: location,
            description: description,
          );
      ref.invalidate(_manageProvider(widget.activityId));
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Activity updated.',
        variant: AppSnackbarVariant.success,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(
        context,
        message: 'Could not save changes. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x3,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Text('Edit Activity', style: AppTypography.titleSheet(context)),
            const SizedBox(height: AppSpacing.x4),
            _SheetField(label: 'TITLE', controller: _titleCtrl),
            const SizedBox(height: AppSpacing.x3),
            _SheetField(label: 'LOCATION', controller: _locationCtrl),
            const SizedBox(height: AppSpacing.x3),
            _SheetField(
              label: 'DESCRIPTION',
              controller: _descCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.x5),
            _SheetPrimaryBtn(
              label: 'Save Changes',
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Share sheet ──────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final link = 'matchup.app/activity/${activity.id}';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.x4),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Text('Share Activity', style: AppTypography.titleSheet(context)),
          const SizedBox(height: AppSpacing.x2),
          Text(
            activity.title,
            style: AppTypography.metaSub(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.x4),

          // Link card
          Container(
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    style: AppTypography.metaSub(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppTappable(
                  semanticLabel: 'Copy link',
                  feedback: AppTapFeedback.scale,
                  minSize: 36,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link));
                    AppSnackbar.show(
                      context,
                      message: 'Link copied.',
                      variant: AppSnackbarVariant.success,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x3,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Copy',
                      style: AppTypography.chipLabel(context).copyWith(
                        color: context.colors.primaryOnSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // Share options
          Row(
            children: [
              _ShareOption(
                icon: Icons.message_rounded,
                label: 'Message',
                color: context.colors.successText,
                bgColor: context.colors.statusSuccessBg,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/chat/${activity.id}');
                },
              ),
              const SizedBox(width: AppSpacing.x3),
              _ShareOption(
                icon: Icons.link_rounded,
                label: 'Copy link',
                color: context.colors.primaryOnSurface,
                bgColor: context.colors.primarySoft,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: link));
                  AppSnackbar.show(
                    context,
                    message: 'Link copied.',
                    variant: AppSnackbarVariant.success,
                  );
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: AppSpacing.x3),
              _ShareOption(
                icon: Icons.ios_share_rounded,
                label: 'More',
                color: context.colors.textPrimary,
                bgColor: context.colors.surfaceSubtle,
                onTap: () {
                  Navigator.of(context).pop();
                  ShareHelper.shareActivity(activity);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: label,
      feedback: AppTapFeedback.scale,
      minSize: 0,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

// ─── Announce sheet ───────────────────────────────────────────────────────────

class _AnnounceSheet extends StatefulWidget {
  const _AnnounceSheet({required this.activityId});
  final String activityId;

  @override
  State<_AnnounceSheet> createState() => _AnnounceSheetState();
}

class _AnnounceSheetState extends State<_AnnounceSheet> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x3,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 20,
                    color: context.colors.warningText,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Text(
                  'Announce to participants',
                  style: AppTypography.titleSheet(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Your message will be sent to the group chat.',
              style: AppTypography.metaSub(context),
            ),
            const SizedBox(height: AppSpacing.x4),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: context.colors.border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: TextField(
                controller: _msgCtrl,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                cursorColor: AppColors.primary,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  hintText:
                      "e.g. 'Reminder: we're playing at Court B tomorrow at 4pm!'",
                  hintStyle: AppTypography.bodyReading(context).copyWith(
                    color: context.colors.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: AppTypography.bodyReading(context),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            _SheetPrimaryBtn(
              label: 'Send Announcement',
              loading: _sending,
              onTap: () async {
                if (_msgCtrl.text.trim().isEmpty) return;
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _sending = true);
                await Future.delayed(const Duration(milliseconds: 600));
                if (!mounted) return;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Announcement sent to group chat.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                nav.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sheet widgets ─────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.metaSub(context).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: maxLines,
            cursorColor: AppColors.primary,
            cursorWidth: 1.5,
            style: AppTypography.bodyMedium(context).copyWith(
              color: context.colors.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetPrimaryBtn extends StatelessWidget {
  const _SheetPrimaryBtn({
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: loading
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: loading ? null : AppShadows.glowPrimary,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.textOnPrimary),
                ),
              )
            : Text(label, style: AppTypography.buttonPrimary),
      ),
    );
  }
}

// ─── Participants section ─────────────────────────────────────────────────────

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({
    required this.activityId,
    required this.roster,
  });
  final String activityId;
  final List<ActivityParticipant> roster;

  @override
  Widget build(BuildContext context) {
    final preview = roster.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Participants (${roster.length})',
                style: AppTypography.titleMedium(context),
              ),
            ),
            AppTappable(
              semanticLabel: 'View all participants',
              feedback: AppTapFeedback.scale,
              minSize: 0,
              onTap: () =>
                  context.push('/activity/$activityId/participants'),
              child: Text(
                'View all',
                style: AppTypography.chipLabel(context).copyWith(
                  color: context.colors.primaryOnSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                _ParticipantRow(item: preview[i]),
                if (i < preview.length - 1)
                  Divider(
                    height: 1,
                    color: context.colors.border,
                    indent: AppSpacing.x4,
                    endIndent: AppSpacing.x4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.item});
  final ActivityParticipant item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: item.avatarUrl,
            name: item.name,
            size: AppAvatarSize.sm,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.labelField(context)),
                Text(
                  item.isOrganizer
                      ? 'Host · ${item.skillLevel}'
                      : item.skillLevel,
                  style: AppTypography.metaSub(context),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: item.isCheckedIn ? 'CHECKED IN' : 'PENDING',
            tone: item.isCheckedIn
                ? StatusTone.checkedIn
                : StatusTone.pending,
          ),
        ],
      ),
    );
  }
}

// ─── Join requests section ────────────────────────────────────────────────────

/// Pending join requests on approval-gated activities (host view).
/// Each row shows the requester with Approve / Decline actions. Only
/// rendered when [requests] is non-empty — the parent guards that.
class _JoinRequestsSection extends StatelessWidget {
  const _JoinRequestsSection({
    required this.requests,
    required this.onApprove,
    required this.onDecline,
  });

  final List<ActivityParticipant> requests;
  final ValueChanged<ActivityParticipant> onApprove;
  final ValueChanged<ActivityParticipant> onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Join requests (${requests.length})',
                style: AppTypography.titleMedium(context),
              ),
            ),
            StatusBadge(label: 'ACTION NEEDED', tone: StatusTone.pending),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (var i = 0; i < requests.length; i++) ...[
                _JoinRequestRow(
                  item: requests[i],
                  onApprove: () => onApprove(requests[i]),
                  onDecline: () => onDecline(requests[i]),
                ),
                if (i < requests.length - 1)
                  Divider(
                    height: 1,
                    color: context.colors.border,
                    indent: AppSpacing.x4,
                    endIndent: AppSpacing.x4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JoinRequestRow extends StatelessWidget {
  const _JoinRequestRow({
    required this.item,
    required this.onApprove,
    required this.onDecline,
  });

  final ActivityParticipant item;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTappable(
              semanticLabel: 'View ${item.name} profile',
              feedback: AppTapFeedback.scale,
              onTap: () => context.push('/player-profile/${item.name}'),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: item.avatarUrl,
                    name: item.name,
                    size: AppAvatarSize.sm,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: AppTypography.labelField(context)),
                        Text(
                          item.skillLevel,
                          style: AppTypography.metaSub(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppTappable(
            semanticLabel: 'Decline ${item.name}',
            feedback: AppTapFeedback.scale,
            minSize: 0,
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: context.colors.border),
              ),
              child: Text(
                'Decline',
                style: AppTypography.chipLabel(context).copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          AppTappable(
            semanticLabel: 'Approve ${item.name}',
            feedback: AppTapFeedback.scale,
            minSize: 0,
            onTap: onApprove,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'Approve',
                style: AppTypography.chipLabel(context).copyWith(
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

// ─── Details section ──────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Max Players', '${activity.capacity} players'),
      ('Skill Level', activity.skillLevel),
      ('Location', activity.location),
      ('Duration', activity.durationLabel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity details', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x3),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rows[i].$1,
                        style: AppTypography.metaSub(context).copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        rows[i].$2,
                        style: AppTypography.labelField(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  Divider(
                    height: 1,
                    color: context.colors.border,
                    indent: AppSpacing.x4,
                    endIndent: AppSpacing.x4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Cancel button ────────────────────────────────────────────────────────────

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: context.colors.errorText, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 18, color: context.colors.errorText),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Cancel Activity',
              style: AppTypography.labelField(context).copyWith(
                color: context.colors.errorText,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Complete button ─────────────────────────────────────────────────────────

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: context.colors.statusSuccessBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.avatarSecondary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.avatarSecondary,
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Mark as Completed',
              style: AppTypography.labelField(context).copyWith(
                color: AppColors.avatarSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
