import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../presentation/widgets/auth_shell.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen>
    with SecureScreenMixin {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_rebuild);
    _confirmController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── Validation rules ──────────────────────────────────────────────────────

  bool get _hasMinLength => _newController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_newController.text);
  bool get _allRulesMet => _hasMinLength && _hasUppercase && _hasNumber;

  bool get _confirmFilled => _confirmController.text.isNotEmpty;
  bool get _passwordsMatch => _newController.text == _confirmController.text;
  bool get _confirmError => _confirmFilled && !_passwordsMatch;

  /// 0–100 strength score
  int get _strength {
    int score = 0;
    if (_hasMinLength) score += 33;
    if (_hasUppercase) score += 33;
    if (_hasNumber) score += 34;
    return score;
  }

  Color get _strengthColor {
    if (_strength < 34) return AppColors.danger;
    if (_strength < 67) return AppColors.warning;
    return AppColors.statusSuccessText;
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

    // TODO: call POST /api/v1/auth/reset-password { email, newPassword }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    HapticFeedback.mediumImpact();
    await _showSuccessDialog();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colors.statusSuccessBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: AppColors.statusSuccessText,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Password Reset!',
                style: AppTypography.headlineSmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Your password has been changed successfully. You can now sign in with your new password.',
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: context.colors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x5),
              SizedBox(
                width: double.infinity,
                child: PrimaryPillButton(
                  label: 'Sign In',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      header: AuthHeaderBar(
        title: 'New Password',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.x4),
            AuthIllustration(
              iconPath: 'assets/images/discovery/icons/shield-check.svg',
            ),
            const SizedBox(height: AppSpacing.x5),
            Text(
              'Create New Password',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                context,
              ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Your new password must be different from previously used passwords.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyReading(
                context,
              ).copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.x5),

            // ── New password ───────────────────────────────────
            _FieldLabel('New Password'),
            const SizedBox(height: AppSpacing.x2),
            _PasswordField(
              controller: _newController,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),

            // Strength bar
            if (_newController.text.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              _StrengthBar(
                strength: _strength,
                color: _strengthColor,
                label: _strengthLabel,
              ),
            ],
            const SizedBox(height: AppSpacing.x4),

            // ── Confirm password ───────────────────────────────
            _FieldLabel('Confirm Password'),
            const SizedBox(height: AppSpacing.x2),
            _PasswordField(
              controller: _confirmController,
              obscure: _obscureConfirm,
              hasError: _confirmError,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            if (_confirmError) ...[
              const SizedBox(height: AppSpacing.x1),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Passwords do not match.',
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x4),

            // ── Requirements checklist ─────────────────────────
            _RequirementRow(met: _hasMinLength, label: 'At least 8 characters'),
            _RequirementRow(
              met: _hasUppercase,
              label: 'Contains an uppercase letter',
            ),
            _RequirementRow(met: _hasNumber, label: 'Contains a number'),
            const SizedBox(height: AppSpacing.x5),

            PrimaryPillButton(
              label: _isSubmitting ? 'Resetting…' : 'Reset Password',
              onPressed: _canSubmit ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.x6),
          ],
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppTypography.inputLabel(context)),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({
    required this.strength,
    required this.color,
    required this.label,
  });
  final int strength;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: strength / 100,
              minHeight: 4,
              backgroundColor: context.colors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Text(
          label,
          style: AppTypography.chipLabel(context).copyWith(color: color),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.hasError = false,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final bool hasError;

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
            'assets/images/auth/lock.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              hasError ? AppColors.danger : context.colors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: AppTypography.bodyFormSecondary(
                context,
              ).copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintStyle: AppTypography.bodyFormSecondary(context),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: obscure ? 'Show password' : 'Hide password',
            child: PressableScale(
              onTap: onToggle,
              child: SvgPicture.asset(
                'assets/images/auth/eye.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  context.colors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.met, required this.label});
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
                  ? AppColors.statusSuccessText
                  : context.colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            label,
            style: AppTypography.bodyMedium(context).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met
                  ? AppColors.statusSuccessText
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
