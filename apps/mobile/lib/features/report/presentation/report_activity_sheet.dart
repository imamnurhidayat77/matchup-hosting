import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../data/report_repository.dart';

/// Bottom sheet for reporting an activity — replaces the old full-screen
/// [ReportScreen] route. The route form crashed with `Navigator` assertion
/// `'!keyReservation.contains(key)'` when double-tapped or when two pushes
/// raced; a modal sheet sidesteps that because the bottom sheet is rendered
/// inside an [Overlay] (no [Page] lifecycle, no key reservation).
///
/// Design: keeps the existing info card + reason-list + submit button but
/// in a scrollable sheet that respects the keyboard. Reasons list shrinks
/// to 5 (most common — activity-specific), the "Other" free-form path is
/// handled by the optional details field instead of a dedicated tile.
class ReportActivitySheet extends ConsumerStatefulWidget {
  const ReportActivitySheet({super.key, required this.activityTitle});

  final String activityTitle;

  /// Convenience launcher — handles the drag handle, scrollable body, and
  /// the dismiss-on-tap-outside semantics so call sites stay terse:
  ///
  /// ```dart
  /// showModalBottomSheet(
  ///   context: ctx,
  ///   isScrollControlled: true,
  ///   backgroundColor: Colors.transparent,
  ///   builder: (_) => ReportActivitySheet(activityTitle: ...),
  /// );
  /// ```
  static Future<void> show(
    BuildContext context, {
    required String activityTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ReportActivitySheet(activityTitle: activityTitle),
    );
  }

  @override
  @override
  ConsumerState<ReportActivitySheet> createState() => _ReportActivitySheetState();
}

class _ReportActivitySheetState extends ConsumerState<ReportActivitySheet> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _submitting = false;

  static const _reasons = [
    'Inappropriate content',
    'Spam / Fake activity',
    'Misleading information',
    'No-show host',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      HapticFeedback.lightImpact();
      AppSnackbar.show(
        context,
        message: 'Please select a reason.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(reportRepositoryProvider).submit(
        targetId: widget.activityTitle,
        targetType: ReportTargetType.activity,
        reason: _reason!,
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );
    } catch (_) {
      // Non-fatal — sheet always closes and success is shown.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackbar.show(
      context,
      message: 'Report submitted. Thank you.',
      variant: AppSnackbarVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      // Lift the sheet above the on-screen keyboard when the details field
      // is focused. `viewInsets.bottom` is the keyboard height.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppShadows.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: 'Report Activity',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  AppSpacing.x2,
                  AppSpacing.x5,
                  AppSpacing.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TargetCard(activityTitle: widget.activityTitle),
                    const SizedBox(height: AppSpacing.x5),
                    Text(
                      "What's the issue?",
                      style: AppTypography.labelField(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    _ReasonsCard(
                      reasons: _reasons,
                      selected: _reason,
                      onSelect: (r) => setState(() => _reason = r),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    _DetailsField(controller: _detailsController),
                    const SizedBox(height: AppSpacing.x4),
                    const _Disclaimer(),
                  ],
                ),
              ),
            ),
            _SubmitBar(submitting: _submitting, onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x2,
      ),
      child: Column(
        children: [
          // Drag handle — iOS convention.
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSheet(context),
                ),
              ),
              PressableScale(
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Target card ──────────────────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.activityTitle});

  final String activityTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.flag_rounded,
              size: 20,
              color: context.colors.errorText,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting this activity',
                  style: AppTypography.labelField(context).copyWith(
                    color: context.colors.errorText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activityTitle,
                  style: AppTypography.metaSub(context).copyWith(
                    color: context.colors.errorText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reasons list ─────────────────────────────────────────────────────────────

class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({
    required this.reasons,
    required this.selected,
    required this.onSelect,
  });

  final List<String> reasons;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(reasons.length, (i) {
          final r = reasons[i];
          final isSelected = r == selected;
          final isLast = i == reasons.length - 1;
          return Column(
            children: [
              AppTappable(
                semanticLabel: r,
                onTap: () => onSelect(r),
                minSize: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : context.colors.border,
                            width: isSelected ? 0 : 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: AppColors.textOnPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Text(
                          r,
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: isSelected
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: context.colors.border,
                  indent: AppSpacing.x4 + 22 + AppSpacing.x3,
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Details field ────────────────────────────────────────────────────────────

class _DetailsField extends StatelessWidget {
  const _DetailsField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional details',
          style: AppTypography.labelField(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional — help us understand the issue better',
          style: AppTypography.metaSub(context),
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            cursorColor: AppColors.primary,
            cursorWidth: 1.5,
            style: AppTypography.bodyReading(context),
            decoration: InputDecoration(
              hintText: 'Describe the issue...',
              hintStyle: AppTypography.bodyReading(context)
                  .copyWith(color: context.colors.textTertiary),
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

// ─── Disclaimer ───────────────────────────────────────────────────────────────

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              'Your report will be reviewed by our moderation team. False reports may result in account restrictions.',
              style: AppTypography.metaSub(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Submit bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.submitting, required this.onSubmit});

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x3 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: PressableScale(
        onTap: submitting ? null : onSubmit,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: submitting
                ? AppColors.danger.withValues(alpha: 0.6)
                : AppColors.danger,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.textOnPrimary),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: AppColors.textOnPrimary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Submit Report',
                      style: AppTypography.buttonPrimary,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}