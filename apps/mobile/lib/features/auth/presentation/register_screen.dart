import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/icon_input_field.dart';
import '../../../core/widgets/pill_buttons.dart';

void _showSocialComingSoon(BuildContext context) {
  AppSnackbar.show(
    context,
    message: 'Social sign-in coming soon.',
    variant: AppSnackbarVariant.info,
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SecureScreenMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // ── Password strength helpers ─────────────────────────────────────────────
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_passwordController.text);

  int get _strength {
    var s = 0;
    if (_hasMinLength) s += 33;
    if (_hasUppercase) s += 33;
    if (_hasNumber) s += 34;
    return s;
  }

  Color get _strengthColor {
    if (_strength < 34) return AppColors.danger;
    if (_strength < 67) return AppColors.warning;
    return AppColors.statusSuccessText;
  }

  String get _strengthLabel {
    if (_passwordController.text.isEmpty) return '';
    if (_strength < 34) return 'Weak';
    if (_strength < 67) return 'Fair';
    return 'Strong';
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/onboarding'); // Re-onboard via preferences after register
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email format';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: close X
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: () => context.go('/welcome'),
                      child: SvgPicture.asset('assets/images/auth/close_x.svg', width: 24, height: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign Up', style: AppTypography.headingDisplay),
                    const SizedBox(height: 6),
                    Text(
                      'Create your MatchUp account',
                      style: AppTypography.bodyFormSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Social row (side-by-side)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: SocialPillButton(
                        label: 'Apple',
                        icon: 'assets/images/auth/apple.svg',
                        expand: false,
                        onPressed: () => _showSocialComingSoon(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialPillButton(
                        label: 'Google',
                        icon: 'assets/images/auth/google.svg',
                        expand: false,
                        onPressed: () => _showSocialComingSoon(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: const OrDivider(label: 'OR SIGN UP WITH EMAIL'),
              ),
              const SizedBox(height: 12),
              // Form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconInputField(
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        controller: _nameController,
                        leadingIcon: 'assets/images/auth/user.svg',
                        keyboardType: TextInputType.name,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      IconInputField(
                        label: 'Email',
                        hint: 'Enter your email',
                        controller: _emailController,
                        leadingIcon: 'assets/images/auth/mail.svg',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      IconInputField(
                        label: 'Password',
                        hint: 'Create a strong password',
                        controller: _passwordController,
                        leadingIcon: 'assets/images/auth/lock.svg',
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        trailing: PasswordToggle(
                          obscure: _obscurePassword,
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      // ── Password strength bar ─────────────────────────
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _strength / 100,
                                  minHeight: 4,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation(_strengthColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _strengthLabel,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _strengthColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _PwRow(met: _hasMinLength, label: 'At least 8 characters'),
                        _PwRow(met: _hasUppercase, label: 'Uppercase letter'),
                        _PwRow(met: _hasNumber, label: 'Contains a number'),
                      ],
                      const SizedBox(height: 12),
                      IconInputField(
                        label: 'Confirm Password',
                        hint: 'Confirm your password',
                        controller: _confirmController,
                        leadingIcon: 'assets/images/auth/lock.svg',
                        obscureText: _obscureConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onRegister(),
                        validator: _validateConfirm,
                        trailing: PasswordToggle(
                          obscure: _obscureConfirm,
                          onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    PrimaryPill(
                      label: _isLoading ? 'Creating...' : 'Create Account',
                      onPressed: _isLoading ? null : _onRegister,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTypography.bodyFormSecondary,
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Sign In',
                              style: AppTypography.bodyFormSecondary.copyWith(
                                color: AppColors.primaryDarker,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const HomeIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact password requirement row — shared with register_screen.
class _PwRow extends StatelessWidget {
  const _PwRow({required this.met, required this.label});
  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              size: 14,
              color: met ? AppColors.statusSuccessText : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: met ? AppColors.statusSuccessText : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
