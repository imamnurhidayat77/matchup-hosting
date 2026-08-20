import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SecureScreenMixin {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Please enter your email address.';
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!re.hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final error = _validateEmail(email);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }
    setState(() {
      _emailError = null;
      _isSubmitting = true;
    });

    // TODO: replace with real API call: POST /api/v1/auth/forgot-password
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Pass email to OTP screen via extra so it can display it
    context.push('/otp-verification', extra: email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _RecoveryHeader(
              title: 'Forgot Password',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.x6),
                    _RecoveryIllustration(
                      iconPath: 'assets/images/auth/lock.svg',
                    ),
                    const SizedBox(height: AppSpacing.x6),
                    Text(
                      'Forgot Your Password?',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      "Enter your email address and we'll send a 6-digit verification code to reset your password.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    // ── Email field ────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Email Address', style: AppTypography.inputLabel),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _EmailInput(
                      controller: _emailController,
                      hasError: _emailError != null,
                      onChanged: (_) {
                        if (_emailError != null) setState(() => _emailError = null);
                      },
                    ),
                    if (_emailError != null) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _emailError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x6),

                    PrimaryPillButton(
                      label: _isSubmitting ? 'Sending…' : 'Send Code',
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: AppSpacing.x6),
                  ],
                ),
              ),
            ),
            _SignInFooter(onSignIn: () => context.go('/login')),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

// ─── Email input ──────────────────────────────────────────────────────────────

class _EmailInput extends StatelessWidget {
  const _EmailInput({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasError ? AppColors.danger : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/auth/mail.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              hasError ? AppColors.danger : AppColors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              onChanged: onChanged,
              textInputAction: TextInputAction.done,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Enter your email',
                hintStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared recovery widgets ──────────────────────────────────────────────────

class _RecoveryHeader extends StatelessWidget {
  const _RecoveryHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

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
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: SvgPicture.asset(
                  'assets/images/discovery/icons/chevron-left.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Text(
            title,
            style: AppTypography.titleLarge.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _RecoveryIllustration extends StatelessWidget {
  const _RecoveryIllustration({required this.iconPath});
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
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
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

class _SignInFooter extends StatelessWidget {
  const _SignInFooter({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x6,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Remember your password?',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSignIn,
            child: Text(
              'Sign In',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDarker,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
