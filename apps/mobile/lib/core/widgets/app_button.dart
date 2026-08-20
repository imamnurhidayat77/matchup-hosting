import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Unified button for MatchUp.
///
/// Variants: [AppButtonVariant.primary], [.secondary], [.ghost], [.danger].
/// Size: [AppButtonSize.md] (default), [.sm], [.lg].
///
/// ```dart
/// AppButton(label: 'Join', onPressed: _join)
/// AppButton.secondary(label: 'Cancel', onPressed: _cancel)
/// AppButton.ghost(label: 'Skip', onPressed: _skip)
/// ```
enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leading,
    this.trailing,
    this.loading = false,
    this.expand = true,
  });

  /// Convenience constructors
  const AppButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    Widget? leading,
    bool loading = false,
    bool expand = true,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: AppButtonVariant.secondary,
         size: size,
         leading: leading,
         loading: loading,
         expand: expand,
       );

  const AppButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool expand = true,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: AppButtonVariant.ghost,
         size: size,
         expand: expand,
       );

  const AppButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool expand = true,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: AppButtonVariant.danger,
         size: size,
         expand: expand,
       );

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool loading;
  final bool expand;

  bool get _disabled => onPressed == null || loading;

  // ── Style resolution ─────────────────────────────────────────────────────

  Color get _bg => switch (variant) {
    AppButtonVariant.primary => AppColors.primary,
    AppButtonVariant.secondary => AppColors.surface,
    AppButtonVariant.ghost => Colors.transparent,
    AppButtonVariant.danger => AppColors.errorLight,
  };

  Color get _fg => switch (variant) {
    AppButtonVariant.primary => Colors.white,
    AppButtonVariant.secondary => AppColors.textPrimary,
    AppButtonVariant.ghost => AppColors.primary,
    AppButtonVariant.danger => AppColors.danger,
  };

  BorderSide get _border => switch (variant) {
    AppButtonVariant.secondary => const BorderSide(color: AppColors.border),
    AppButtonVariant.danger => const BorderSide(color: AppColors.errorLight),
    _ => BorderSide.none,
  };

  List<BoxShadow> get _shadow => switch (variant) {
    AppButtonVariant.primary when !_disabled => AppShadows.glowPrimary,
    _ => const [],
  };

  EdgeInsets get _padding => switch (size) {
    AppButtonSize.sm => const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    AppButtonSize.md => const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 14,
    ),
    AppButtonSize.lg => const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
  };

  double get _fontSize => switch (size) {
    AppButtonSize.sm => 13,
    AppButtonSize.md => 15,
    AppButtonSize.lg => 16,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: !_disabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _disabled ? 0.55 : 1.0,
        child: GestureDetector(
          onTap: _disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          child: Container(
            width: expand ? double.infinity : null,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.fromBorderSide(_border),
              boxShadow: _shadow,
            ),
            padding: _padding,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_fg),
                    ),
                  )
                else ...[
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: AppTypography.buttonPrimary.copyWith(
                      color: _fg,
                      fontSize: _fontSize,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
