import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';

/// Theme-aware confirmation dialog used across the app.
///
/// Always pass `context` from the widget that opens the dialog — the builder
/// uses `InheritedTheme.captureAll` to propagate `AppColorTokens` into the
/// dialog so `context.colors.*` resolves correctly in dark mode.
///
/// ```dart
/// final yes = await AppDialog.confirm(
///   context,
///   title: 'Leave Activity?',
///   body: 'You can re-join later if spots are available.',
///   confirmLabel: 'Leave',
///   destructive: true,
/// );
/// ```
class AppDialog {
  AppDialog._();

  /// Shows a two-button confirm/cancel dialog. Returns `true` if the user
  /// taps the confirm button, `false` / `null` otherwise.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) {
    final captured = InheritedTheme.captureAll(
      context,
      _AppDialogContent(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return showDialog<bool>(
      context: context,
      builder: (_) => captured,
    );
  }
}

class _AppDialogContent extends StatelessWidget {
  const _AppDialogContent({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final confirmColor =
        destructive ? context.colors.errorText : context.colors.primaryOnSurface;

    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: context.colors.border),
      ),
      title: Text(
        title,
        style: AppTypography.titleMedium(context),
      ),
      content: Text(
        body,
        style: AppTypography.bodyMedium(context).copyWith(
          color: context.colors.textSecondary,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: AppTypography.labelField(context).copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: AppTypography.labelField(context).copyWith(
              color: confirmColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
