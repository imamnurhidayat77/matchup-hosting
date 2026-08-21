import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/icon_input_field.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';
import 'widgets/auth_shell.dart';

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
      // Resume cached session from secure storage via auth provider.
      await ref.read(authStateProvider.notifier).checkSession();
      // If still unauthenticated (no stored token), fall back gracefully.
      if (!mounted) return;
      final status = ref.read(authStatusProvider);
      if (status != AuthStatus.authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No saved session. Please sign in with your password.',
            ),
          ),
        );
      }
      // Router redirect fires automatically if session is valid.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric authentication failed')),
      );
    }
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // TODO: replace with real API call when backend is ready.
      // For now we simulate a successful login by storing a placeholder token
      // so the auth guard lets the user through.
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      await ref
          .read(authStateProvider.notifier)
          .signIn(
            accessToken: 'demo_access_token',
            refreshToken: 'demo_refresh_token',
            userId: 'demo_user_001',
          );
      // Router redirect fires automatically — no manual context.go needed.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
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

  Widget _biometricButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: context.colors.primaryOnSurface),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x3,
        ),
      ),
      icon: AppIcon.material(
        Icons.fingerprint,
        color: context.colors.primaryOnSurface,
      ),
      label: Text(
        'Use Biometrics',
        style: AppTypography.bodyFormSecondary(context).copyWith(
          color: context.colors.primaryOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: _onBiometricLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      scrollPadding: EdgeInsets.zero,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          AppSpacing.x3,
          AppSpacing.x6,
          0,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AuthCloseButton(onTap: () => context.go('/welcome')),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.x4),
              Text('Sign In', style: AppTypography.headingDisplay(context)),
              const SizedBox(height: AppSpacing.x2),
              Text(
                "Let's sign in to your MatchUp account",
                style: AppTypography.bodyFormSecondary(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        // Social buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Column(
            children: [
              SocialPillButton(
                label: 'Sign in with Apple',
                icon: 'assets/images/auth/apple.svg',
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.x3),
              SocialPillButton(
                label: 'Sign in with Google',
                icon: 'assets/images/auth/google.svg',
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        // Form
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: AppSpacing.x4),
                IconInputField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  leadingIcon: 'assets/images/auth/lock.svg',
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onLogin(),
                  validator: _validatePassword,
                  trailing: PasswordToggle(
                    obscure: _obscurePassword,
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Forgot password?',
                    child: PressableScale(
                      onTap: () => context.go('/forgot-password'),
                      child: Text(
                        'Forgot Password?',
                        style: AppTypography.inputLabel(context).copyWith(
                          color: context.colors.primaryOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        // Primary action + sign up prompt
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Column(
            children: [
              PrimaryPill(
                label: _isLoading ? 'Signing in...' : 'Sign In',
                onPressed: _isLoading ? null : _onLogin,
              ),
              if (_biometricAvailable) ...[
                const SizedBox(height: AppSpacing.x3),
                _biometricButton(context),
              ],
              const SizedBox(height: AppSpacing.x4),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.x1,
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
                          style: AppTypography.bodyFormSecondary(context)
                              .copyWith(
                                color: context.colors.primaryOnSurface,
                                fontWeight: FontWeight.w700,
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
        const SizedBox(height: AppSpacing.x4),
      ],
    );
  }
}
