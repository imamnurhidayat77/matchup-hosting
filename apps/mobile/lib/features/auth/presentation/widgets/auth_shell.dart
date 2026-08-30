import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../../../core/widgets/home_indicator.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// Shared shell for all auth & recovery screens.
///
/// Provides the standard Scaffold + SafeArea + scrollable body + bottom
/// content, so every auth screen only supplies its form content.
/// [bottom] is pinned below the scroll area (e.g. submit button, footer).
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.children,
    this.header,
    this.bottom,
    this.scrollPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
    this.backgroundColor,
    this.bottomPadding = const EdgeInsets.fromLTRB(
      AppSpacing.x6,
      AppSpacing.x4,
      AppSpacing.x6,
      AppSpacing.x2,
    ),
  });

  /// Optional pinned header (top nav row: close / back button).
  final Widget? header;

  /// Scrollable body content.
  final List<Widget> children;

  /// Pinned bottom widget (CTA button, sign-in footer).
  final Widget? bottom;

  /// Horizontal padding for the scrollable body.
  final EdgeInsetsGeometry scrollPadding;

  final EdgeInsetsGeometry bottomPadding;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            Expanded(
              child: SingleChildScrollView(
                padding: scrollPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            if (bottom != null) Padding(padding: bottomPadding, child: bottom),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Circular close (X) button used at the top-left of login / register.
class AuthCloseButton extends StatelessWidget {
  const AuthCloseButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: PressableScale(
        onTap: onTap,
        child: SvgPicture.asset(
          'assets/images/auth/close_x.svg',
          width: 24,
          height: 24,
        ),
      ),
    );
  }
}

/// Circular back button used at the top-left of recovery screens.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: context.colors.border),
          ),
          child: SvgPicture.asset(
            'assets/images/discovery/icons/chevron-left.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              context.colors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard header row: back button + title (recovery pattern).
class AuthHeaderBar extends StatelessWidget {
  const AuthHeaderBar({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x2,
      ),
      child: Row(
        children: [
          AuthBackButton(onTap: onBack),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(title, style: AppTypography.titleScreen(context)),
          ),
        ],
      ),
    );
  }
}

/// Concentric-circle illustration used on recovery screens.
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, required this.iconPath});

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: context.colors.primarySoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          iconPath,
          width: 32,
          height: 32,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Centered "back to sign in" footer link used on recovery screens.
class AuthSignInFooter extends StatelessWidget {
  const AuthSignInFooter({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Remember your password? ',
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(color: context.colors.textSecondary),
        ),
        PressableScale(
          onTap: onSignIn,
          child: Text(
            'Sign In',
            style: AppTypography.bodyMedium(context).copyWith(
              color: context.colors.primaryOnSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
