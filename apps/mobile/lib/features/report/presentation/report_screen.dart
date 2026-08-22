import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/pressable_scale.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetName,
  });

  final String targetType; // 'user' or 'activity'
  final String targetName;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _submitting = false;

  static const _reasons = [
    'Inappropriate content',
    'Spam / Fake activity',
    'Harassment',
    'Misleading information',
    'No-show host',
    'Violation of rules',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      AppSnackbar.show(
        context,
        message: 'Please select a reason.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _submitting = false);
    AppSnackbar.show(
      context,
      message: 'Report submitted. Thank you.',
      variant: AppSnackbarVariant.success,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      safeAreaTop: true,
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x3,
              AppSpacing.x5,
              AppSpacing.x3,
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  child: PressableScale(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: context.colors.border),
                        boxShadow: AppShadows.card,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    'Report ${_capitalize(widget.targetType)}',
                    style: AppTypography.titleSheet(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 38),
              ],
            ),
          ),

          // ── Scrollable body ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x4,
                AppSpacing.x5,
                AppSpacing.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target card
                  _TargetCard(
                    targetType: widget.targetType,
                    targetName: widget.targetName,
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // Reason section
                  _SectionCard(
                    title: 'What\'s the issue?',
                    child: Column(
                      children: _reasons.map((r) {
                        final selected = r == _reason;
                        return _ReasonTile(
                          label: r,
                          selected: selected,
                          onTap: () => setState(() => _reason = r),
                          isLast: r == _reasons.last,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Additional details
                  _SectionCard(
                    title: 'Additional details',
                    subtitle: 'Optional — help us understand the issue better',
                    child: Container(
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
                        controller: _detailsController,
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
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Disclaimer
                  Container(
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
                          color: context.colors.textTertiary,
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
                  ),
                ],
              ),
            ),
          ),

          // ── Submit bar ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x3,
              AppSpacing.x5,
              AppSpacing.x5 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface,
              boxShadow: AppShadows.bottomBar,
            ),
            child: PressableScale(
              onTap: _submitting ? null : _submit,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: _submitting
                      ? AppColors.danger.withValues(alpha: 0.6)
                      : AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.textOnPrimary,
                          ),
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
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Target card ──────────────────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.targetType, required this.targetName});
  final String targetType;
  final String targetName;

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
            child: const Icon(
              Icons.flag_rounded,
              size: 20,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting this $targetType',
                  style: AppTypography.labelField(context).copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  targetName,
                  style: AppTypography.metaSub(context).copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
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

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium(context)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTypography.metaSub(context)),
          ],
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

// ─── Reason tile ──────────────────────────────────────────────────────────────

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLast,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTappable(
          semanticLabel: label,
          onTap: onTap,
          minSize: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
            child: Row(
              children: [
                // Custom radio circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : context.colors.border,
                      width: selected ? 0 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
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
                    label,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: selected
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
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
            indent: 34,
          ),
      ],
    );
  }
}
