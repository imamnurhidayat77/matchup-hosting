import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../domain/appeal_model.dart';

/// Interstitial for suspended accounts — the ONLY screen a suspended user
/// can reach (see the router's auth redirect).
///
/// Best-practice notes, enforced here:
/// - The session stays alive: signing out would strand the user with no
///   way back in, and the appeal endpoints need the tokens.
/// - One pending appeal at a time (backend 409s dupes) — the UI shows the
///   pending state instead of a second form.
/// - Decisions surface here via `GET /appeals/me` plus the "Check again"
///   probe (`GET /users/me` → 200 means reactivated).
class SuspendedScreen extends ConsumerStatefulWidget {
  const SuspendedScreen({super.key});

  @override
  ConsumerState<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends ConsumerState<SuspendedScreen> {
  final _statementController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _checking = false;
  List<AppealModel> _appeals = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  AppealModel? get _pending {
    try {
      return _appeals.firstWhere((a) => a.status == AppealStatus.pending);
    } catch (_) {
      return null;
    }
  }

  AppealModel? get _latestDecided {
    final decided = _appeals
        .where((a) => a.status != AppealStatus.pending)
        .toList();
    if (decided.isEmpty) return null;
    decided.sort((a, b) => (b.decidedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.decidedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return decided.first;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final appeals = await ref.read(appealRepositoryProvider).myAppeals();
      if (mounted) setState(() => _appeals = appeals);
    } on ApiException catch (e) {
      if (mounted && !e.isAccountSuspended) {
        AppSnackbar.show(
          context,
          message: e.userMessage,
          variant: AppSnackbarVariant.error,
        );
      }
      // Suspended-token errors are expected here (this IS the suspended
      // screen) — the interstitial itself is the content.
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Could not load your appeals. Please try again.',
          variant: AppSnackbarVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final statement = _statementController.text.trim();
    if (statement.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Please explain what happened before submitting.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final created = await ref
          .read(appealRepositoryProvider)
          .submitSuspensionAppeal(statement: statement);
      _statementController.clear();
      if (!mounted) return;
      setState(() => _appeals = [created, ..._appeals]);
      AppSnackbar.show(
        context,
        message: 'Appeal submitted. We\'ll notify you of the decision.',
        variant: AppSnackbarVariant.success,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // A pending appeal already exists — show it instead of erroring.
        await _reload();
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: 'You already have an appeal under review.',
          variant: AppSnackbarVariant.info,
        );
      } else if (!e.isAccountSuspended) {
        AppSnackbar.show(
          context,
          message: e.userMessage,
          variant: AppSnackbarVariant.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not submit your appeal. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    try {
      final ok = await ref.read(authStateProvider.notifier).refreshSuspension();
      if (!mounted) return;
      if (ok) {
        // Router redirect (suspended → authenticated) moves us along.
        AppSnackbar.show(
          context,
          message: 'Welcome back! Your account is active again.',
          variant: AppSnackbarVariant.success,
        );
      } else {
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showHomeIndicator: false,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  AppSpacing.x8,
                  AppSpacing.x5,
                  AppSpacing.x8,
                ),
                children: [
                  _HeaderIcon(),
                  const SizedBox(height: AppSpacing.x5),
                  Text(
                    'Your account is suspended',
                    style: AppTypography.headlineSmall(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'You can\'t join or host activities right now. '
                    'If you believe this is a mistake, submit one appeal '
                    'below — our team reviews every appeal.',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  ..._statusSection(context),
                  const SizedBox(height: AppSpacing.x5),
                  AppButton(
                    label: 'Check again',
                    onPressed: _checking ? null : _checkAgain,
                    loading: _checking,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  AppButton.ghost(
                    label: 'Sign out',
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).signOut(),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _statusSection(BuildContext context) {
    final pending = _pending;
    if (pending != null) return [_PendingCard(appeal: pending)];

    final decided = _latestDecided;
    if (decided != null && decided.status == AppealStatus.rejected) {
      return [
        _DecisionCard(appeal: decided),
        const SizedBox(height: AppSpacing.x4),
      ];
    }
    if (decided != null && decided.status == AppealStatus.approved) {
      return [
        _DecisionCard(appeal: decided),
        const SizedBox(height: AppSpacing.x4),
      ];
    }

    // No appeals yet (or only decided ones cleared) — the form.
    return [
      _GuidelinesCard(),
      const SizedBox(height: AppSpacing.x4),
      Text('Your appeal', style: AppTypography.labelField(context)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: context.colors.border),
        ),
        child: TextField(
          controller: _statementController,
          style: AppTypography.bodyFormSecondary(
            context,
          ).copyWith(color: context.colors.textPrimary),
          maxLines: 5,
          minLines: 4,
          maxLength: 2000,
          decoration: InputDecoration.collapsed(
            hintText:
                'Explain what happened and why you believe this was a mistake…',
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.x3),
      AppButton(
        label: 'Submit appeal',
        onPressed: _submitting ? null : _submit,
        loading: _submitting,
      ),
    ];
  }
}

class _HeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: context.colors.warningBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.colors.warningText.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.gavel_outlined,
          size: 34,
          color: context.colors.warningText,
        ),
      ),
    );
  }
}

class _GuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Make it count — you get one pending appeal', style: AppTypography.labelField(context)),
          const SizedBox(height: AppSpacing.x2),
          for (final tip in const [
            'Say what happened, factually and briefly.',
            'Name the activity or message if you know what was flagged.',
            'Being polite goes further than protesting.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppTypography.bodyMedium(context)),
                  Expanded(
                    child: Text(
                      tip,
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: context.colors.textSecondary,
                      ),
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

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.appeal});
  final AppealModel appeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: context.colors.primaryOnSurface.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: context.colors.primaryOnSurface,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appeal under review', style: AppTypography.labelField(context)),
                const SizedBox(height: 2),
                Text(
                  'We\'ll notify you as soon as there\'s a decision. '
                  'Submitting again won\'t speed things up.',
                  style: AppTypography.metaSub(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.appeal});
  final AppealModel appeal;

  @override
  Widget build(BuildContext context) {
    final approved = appeal.status == AppealStatus.approved;
    final fg = approved
        ? context.colors.successText
        : context.colors.errorText;
    final bg = approved
        ? context.colors.statusSuccessBg
        : context.colors.errorLight;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            approved
                ? Icons.check_circle_outline_rounded
                : Icons.highlight_off_rounded,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved ? 'Appeal approved' : 'Appeal not approved',
                  style: AppTypography.labelField(context),
                ),
                const SizedBox(height: 2),
                Text(
                  approved
                      ? 'Tap "Check again" below to get back in.'
                      : (appeal.adminNote != null &&
                              appeal.adminNote!.isNotEmpty)
                          ? 'Note from our team: ${appeal.adminNote}'
                          : 'Our decision is final for this appeal.',
                  style: AppTypography.metaSub(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
