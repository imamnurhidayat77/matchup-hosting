import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pressable_scale.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen>
    with SecureScreenMixin {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool get _hasMinLength => _newController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_newController.text);
  bool get _allRulesMet => _hasMinLength && _hasUppercase && _hasNumber;

  bool get _confirmFilled => _confirmController.text.isNotEmpty;
  bool get _passwordsMatch => _newController.text == _confirmController.text;
  bool get _confirmError => _confirmFilled && !_passwordsMatch;

  int get _strength {
    int score = 0;
    if (_hasMinLength) score += 33;
    if (_hasUppercase) score += 33;
    if (_hasNumber) score += 34;
    return score;
  }

  Color _strengthColor(BuildContext context) {
    if (_strength < 34) return context.colors.errorText;
    if (_strength < 67) return context.colors.warningText;
    return context.colors.successText;
  }

  String get _strengthLabel {
    if (_newController.text.isEmpty) return '';
    if (_strength < 34) return 'Weak';
    if (_strength < 67) return 'Fair';
    return 'Strong';
  }

  bool get _canSubmit =>
      _allRulesMet && _passwordsMatch && _confirmFilled && !_isSubmitting;

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        email: widget.email,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _showSuccess();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      // show error inline — stay on this screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Password reset failed.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccess() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SuccessSheet(onSignIn: () => Navigator.of(context).pop()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final availableHeight = screenHeight - safeTop - safeBottom;

    return AppScaffold(
      safeAreaTop: true,
      showHomeIndicator: true,
      backgroundColor: context.colors.background,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Back',
                      child: PressableScale(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 30,
                      color: context.colors.primaryOnSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Title + subtitle
                  Text(
                    'Create New Password',
                    style: AppTypography.headingDisplay(context),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Your new password must be different from your previously used password.',
                    style: AppTypography.bodyFormSecondary(context),
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // New password
                  Text('New Password', style: AppTypography.labelField(context)),
                  const SizedBox(height: AppSpacing.x2),
                  _PasswordField(
                    controller: _newController,
                    hint: 'Create a strong password',
                    obscure: _obscureNew,
                    onToggle: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),

                  // Strength bar
                  if (_newController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: LinearProgressIndicator(
                              value: _strength / 100,
                              minHeight: 4,
                              backgroundColor: context.colors.border,
                              valueColor: AlwaysStoppedAnimation(_strengthColor(context)),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          _strengthLabel,
                          style: AppTypography.metaSub(context)
                              .copyWith(color: _strengthColor(context)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x3),

                  // Confirm password
                  Text(
                    'Confirm Password',
                    style: AppTypography.labelField(context),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  _PasswordField(
                    controller: _confirmController,
                    hint: 'Confirm your password',
                    obscure: _obscureConfirm,
                    hasError: _confirmError,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  if (_confirmError) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      'Passwords do not match.',
                      style: AppTypography.metaSub(context)
                          .copyWith(color: context.colors.errorText),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x4),

                  // Requirements checklist
                  _Requirement(met: _hasMinLength, label: 'At least 8 characters'),
                  _Requirement(met: _hasUppercase, label: 'Contains an uppercase letter'),
                  _Requirement(met: _hasNumber, label: 'Contains a number'),
                  const SizedBox(height: AppSpacing.x5),

                  // Reset button
                  PressableScale(
                    onTap: _canSubmit ? _submit : null,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _canSubmit
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: _canSubmit ? AppShadows.glowPrimary : null,
                      ),
                      alignment: Alignment.center,
                      child: _isSubmitting
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
                              'Reset Password',
                              style: AppTypography.buttonPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Password field ───────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      cursorColor: AppColors.primary,
      cursorWidth: 1.5,
      style: AppTypography.bodyReading(context).copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyReading(context).copyWith(
          color: context.colors.textTertiary,
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.x3),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: context.colors.textTertiary,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: context.colors.textTertiary,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: hasError
            ? context.colors.errorLight
            : context.colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3 + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(
            color: hasError ? context.colors.errorText : context.colors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(
            color: hasError ? context.colors.errorText : AppColors.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

// ─── Requirement row ──────────────────────────────────────────────────────────

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});
  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              size: 16,
              color: met
                  ? context.colors.successText
                  : context.colors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            label,
            style: AppTypography.metaSub(context).copyWith(
              fontSize: 13,
              color: met
                  ? context.colors.successText
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success bottom sheet ─────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x4,
        AppSpacing.x5,
        bottomPad + AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.x5),

          // Check icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.statusSuccessBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.statusSuccessText, // Displayed on white in
              // confirmation card; AA verified at 5.93:1.
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          Text(
            'Password Reset!',
            style: AppTypography.titleSheet(context).copyWith(
              color: context.colors.successText,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Your password has been changed successfully. You can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyFormSecondary(context),
          ),
          const SizedBox(height: AppSpacing.x5),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              onPressed: onSignIn,
              child: Text('Sign In', style: AppTypography.buttonPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
