import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pressable_scale.dart';

void _showSocialComingSoon(BuildContext context) {
  AppSnackbar.show(
    context,
    message: 'Social sign-in coming soon.',
    variant: AppSnackbarVariant.info,
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SecureScreenMixin {
  bool _biometricAvailable = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _detectBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _detectBiometrics() async {
    final available = await BiometricService.instance.isAvailable;
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _onBiometricLogin() async {
    final ok = await BiometricService.instance.authenticate(
      reason: 'Authenticate to sign in to MatchUp',
    );
    if (!mounted) return;
    if (ok) {
      await ref.read(authStateProvider.notifier).checkSession();
      if (!mounted) return;
      final status = ref.read(authStatusProvider);
      if (status != AuthStatus.authenticated) {
        AppSnackbar.show(
          context,
          message: 'No saved session. Please sign in with your password.',
          variant: AppSnackbarVariant.info,
        );
      }
    } else {
      AppSnackbar.show(
        context,
        message: 'Biometric authentication failed.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await ref.read(authStateProvider.notifier).signIn(
        accessToken: 'demo_access_token',
        refreshToken: 'demo_refresh_token',
        userId: 'demo_user_001',
      );
      // Router redirect fires automatically — no manual context.go needed.
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Login failed. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
      return 'Invalid email format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom;

    return AppScaffold(
      safeAreaTop: true,
      showHomeIndicator: true,
      backgroundColor: AppColors.textOnPrimary, // Pure white
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x3,
            AppSpacing.x5,
            AppSpacing.x6,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight - AppSpacing.x3 - AppSpacing.x6,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        child: PressableScale(
                          onTap: () => context.go('/welcome'),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              size: 24,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),

                    // Title
                    Text(
                      'Sign In',
                      style: AppTypography.headingDisplay(context),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      "Let's sign in to your MatchUp account",
                      style: AppTypography.bodyFormSecondary(context),
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Social buttons — side by side
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            label: 'Google',
                            icon: Icons.circle_outlined,
                            onTap: () => _showSocialComingSoon(context),
                            isOutline: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Expanded(
                          child: _SocialButton(
                            label: 'Apple',
                            icon: Icons.apple_rounded,
                            onTap: () => _showSocialComingSoon(context),
                            isOutline: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: context.colors.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x3,
                          ),
                          child: Text(
                            'OR SIGN IN WITH EMAIL',
                            style: AppTypography.metaSub(context).copyWith(
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: context.colors.border),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Email
                    Text('Email', style: AppTypography.labelField(context)),
                    const SizedBox(height: AppSpacing.x2),
                    _TextField(
                      controller: _emailController,
                      hint: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.x3),

                    // Password
                    Text(
                      'Password',
                      style: AppTypography.labelField(context),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _TextField(
                      controller: _passwordController,
                      hint: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onLogin(),
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF6B7280),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        button: true,
                        label: 'Forgot password?',
                        child: PressableScale(
                          onTap: () => context.go('/forgot-password'),
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.labelField(context).copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    // Sign In button
                    PressableScale(
                      onTap: _isLoading ? null : _onLogin,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow:
                              _isLoading ? null : AppShadows.glowPrimary,
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
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
                            : Text(
                                'Sign In',
                                style: AppTypography.buttonPrimary,
                              ),
                      ),
                    ),

                    // Biometric login
                    if (_biometricAvailable) ...[
                      const SizedBox(height: AppSpacing.x3),
                      Semantics(
                        button: true,
                        label: 'Use biometrics',
                        child: PressableScale(
                          onTap: _onBiometricLogin,
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.primary),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.x2),
                                Text(
                                  'Use Biometrics',
                                  style: AppTypography.labelField(context)
                                      .copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x4),

                    // Don't have an account? Sign Up
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTypography.bodyFormSecondary(context),
                          ),
                          Semantics(
                            button: true,
                            label: 'Sign up',
                            child: PressableScale(
                              onTap: () => context.go('/register'),
                              child: Text(
                                'Sign Up',
                                style:
                                    AppTypography.bodyFormSecondary(context)
                                        .copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.primary,
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isOutline,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isOutline
                ? context.colors.surface
                : const Color(0xFF000000),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: isOutline
                ? Border.all(color: context.colors.border, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isOutline
                    ? context.colors.textSecondary
                    : AppColors.textOnPrimary,
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                label,
                style: AppTypography.labelField(context).copyWith(
                  color: isOutline
                      ? context.colors.textPrimary
                      : AppColors.textOnPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  // Design-specified exact values for this screen's input fields —
  // intentionally not routed through AppColors tokens since they don't
  // match existing surfaceMuted (#F1F5F9) / textTertiary (#9CA3AF).
  static const Color _fieldFillColor = Color(0xFFF9FAFB);
  static const Color _fieldBorderColor = Color(0xFFE5E7EB);
  static const Color _placeholderColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        cursorColor: AppColors.primary,
        cursorWidth: 1.5,
        style: AppTypography.bodyReading(context).copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodyReading(context).copyWith(
            color: _placeholderColor,
            fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.x3),
            child: Icon(
              icon,
              size: 18,
              color: _placeholderColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _fieldFillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3 + 2,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: _fieldBorderColor, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: _fieldBorderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.danger, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.danger, width: 2),
          ),
        ),
      ),
    );
  }
}
