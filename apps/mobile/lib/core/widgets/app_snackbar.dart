import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppSnackbarVariant { success, error, info, warning }

/// Consistent snackbar/toast for MatchUp.
///
/// ```dart
/// AppSnackbar.show(context, message: 'Activity created!');
/// AppSnackbar.show(context, message: 'Failed', variant: AppSnackbarVariant.error);
/// ```
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarVariant variant = AppSnackbarVariant.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _AppSnackbarContent(
            message: message,
            variant: variant,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
  }
}

class _AppSnackbarContent extends StatelessWidget {
  const _AppSnackbarContent({
    required this.message,
    required this.variant,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppSnackbarVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _bg => switch (variant) {
        AppSnackbarVariant.success => AppColors.statusSuccessBg,
        AppSnackbarVariant.error => AppColors.errorLight,
        AppSnackbarVariant.warning => AppColors.warningBg,
        AppSnackbarVariant.info => AppColors.primarySoft,
      };

  Color get _fg => switch (variant) {
        AppSnackbarVariant.success => AppColors.statusSuccessText,
        AppSnackbarVariant.error => AppColors.danger,
        AppSnackbarVariant.warning => AppColors.warning,
        AppSnackbarVariant.info => AppColors.primaryDarker,
      };

  IconData get _icon => switch (variant) {
        AppSnackbarVariant.success => Icons.check_circle_outline_rounded,
        AppSnackbarVariant.error => Icons.error_outline_rounded,
        AppSnackbarVariant.warning => Icons.warning_amber_rounded,
        AppSnackbarVariant.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fg.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, color: _fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: _fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTypography.bodyMedium.copyWith(
                  color: _fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
