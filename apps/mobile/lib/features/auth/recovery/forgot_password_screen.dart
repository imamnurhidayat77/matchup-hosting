import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../presentation/widgets/auth_shell.dart';

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
    return AuthShell(
      header: AuthHeaderBar(
        title: 'Forgot Password',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      bottom: AuthSignInFooter(onSignIn: () => context.go('/login')),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.x6),
            AuthIllustration(iconPath: 'assets/images/auth/lock.svg'),
            const SizedBox(height: AppSpacing.x6),
            Text(
              'Forgot Your Password?',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                context,
              ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              "Enter your email address and we'll send a 6-digit verification code to reset your password.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyReading(
                context,
              ).copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.x6),

            // ── Email field ────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Email Address',
                style: AppTypography.inputLabel(context),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            _EmailInput(
              controller: _emailController,
              hasError: _emailError != null,
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
            ),
            if (_emailError != null) ...[
              const SizedBox(height: AppSpacing.x1),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _emailError!,
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: AppColors.danger),
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
      ],
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
        vertical: AppSpacing.x3 + 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasError ? AppColors.danger : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/auth/mail.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              hasError ? AppColors.danger : context.colors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              onChanged: onChanged,
              textInputAction: TextInputAction.done,
              style: AppTypography.bodyFormSecondary(
                context,
              ).copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Enter your email',
                hintStyle: AppTypography.bodyFormSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
