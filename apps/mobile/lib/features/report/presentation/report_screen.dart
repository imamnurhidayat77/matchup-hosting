import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';

class ReportScreen extends StatefulWidget {
  final String targetType; // 'user' or 'activity'
  final String targetName;

  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetName,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _detailsController = TextEditingController();
  String _reportReason = 'Inappropriate content';
  bool _isSubmitting = false;

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

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    AppSnackbar.show(
      context,
      message: 'Report submitted.',
      variant: AppSnackbarVariant.success,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold.detail(
      title: 'Report',
      showHomeIndicator: false, // reached from inside ShellRoute screens.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          AppSpacing.x2,
          AppSpacing.x6,
          AppSpacing.x8,
        ),
        children: [
          _TargetBanner(
            targetType: widget.targetType,
            targetName: widget.targetName,
          ),
          const SizedBox(height: AppSpacing.x8),
          Text('Reason', style: AppTypography.titleMedium(context)),
          const SizedBox(height: AppSpacing.x3),
          RadioGroup<String>(
            groupValue: _reportReason,
            onChanged: (v) => setState(() => _reportReason = v ?? ''),
            child: Column(
              children: _reasons
                  .map(
                    (r) => RadioListTile(
                      title: Text(r, style: AppTypography.bodyLarge(context)),
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          AppTextField.form(
            label: 'ADDITIONAL DETAILS (OPTIONAL)',
            controller: _detailsController,
            hint: 'Describe the issue...',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.x6),
          AppButton.danger(
            label: _isSubmitting ? 'Submitting...' : 'Submit Report',
            onPressed: _isSubmitting ? null : _submitReport,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Your report will be reviewed by moderation staff.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(context),
          ),
        ],
      ),
    );
  }
}

class _TargetBanner extends StatelessWidget {
  const _TargetBanner({required this.targetType, required this.targetName});
  final String targetType;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const AppIcon.material(
            Icons.flag,
            size: AppIconSize.xl,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report $targetType',
                  style: AppTypography.titleLarge(
                    context,
                  ).copyWith(color: AppColors.error),
                ),
                Text(
                  targetName,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
