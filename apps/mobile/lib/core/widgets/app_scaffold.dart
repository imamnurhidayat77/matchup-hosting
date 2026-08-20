import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'home_indicator.dart';

/// Standard scaffold for MatchUp screens.
///
/// Handles safe area, background color, and optional pinned bottom action.
/// All top-level screens should use this instead of raw [Scaffold].
///
/// ```dart
/// AppScaffold(
///   title: 'My Activities',
///   actions: [NotificationIconButton(onTap: ...)],
///   body: ...,
/// )
/// ```
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.bottomBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.safeAreaTop = true,
    this.showHomeIndicator = true,
    this.headerPadding = const EdgeInsets.fromLTRB(
      AppSpacing.x5,
      AppSpacing.x3,
      AppSpacing.x5,
      AppSpacing.x2,
    ),
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool safeAreaTop;
  final bool showHomeIndicator;
  final EdgeInsetsGeometry headerPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        top: safeAreaTop,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              AppScreenHeader(
                title: title!,
                leading: leading,
                actions: actions,
                padding: headerPadding,
              ),
            Expanded(child: body),
            ?bottomBar,
            if (showHomeIndicator) const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Consistent screen header: back/leading slot + title + actions.
/// Used by [AppScaffold] and directly by screens that need custom body layout.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.x5,
      AppSpacing.x3,
      AppSpacing.x5,
      AppSpacing.x2,
    ),
    this.style,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              title,
              style: style ??
                  AppTypography.headlineSmall.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
        ],
      ),
    );
  }
}

/// Standard back button aligned with [AppScreenHeader].
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onPressed != null) {
            onPressed!();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
