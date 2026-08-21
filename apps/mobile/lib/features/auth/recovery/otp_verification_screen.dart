import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../presentation/widgets/auth_shell.dart';

/// Receives the email address via GoRouter's [GoRouterState.extra].
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, this.email = ''});
  final String email;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin, SecureScreenMixin {
  static const _codeLength = 6;
  final _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isVerifying = false;
  bool _hasError = false;

  // Shake animation for wrong OTP
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _shakeAnimation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining--;
      });
    });
  }

  String get _timerText {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length != _codeLength) return;
    setState(() => _isVerifying = true);

    // TODO: call POST /api/v1/auth/verify-otp  { email, code }
    // Simulate: code "123456" is always valid in demo mode.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (_enteredCode == '123456') {
      HapticFeedback.mediumImpact();
      // Pass email forward to new-password screen
      context.push('/new-password', extra: widget.email);
    } else {
      _showError();
    }
  }

  void _showError() {
    HapticFeedback.heavyImpact();
    setState(() => _hasError = true);
    _shakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _hasError = false);
      // Clear all boxes
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    });
    AppSnackbar.show(
      context,
      message: 'Incorrect code. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  }

  void _onOtpChanged(int index, String value) {
    // Handle paste: if value has multiple chars, distribute across boxes
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _codeLength && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty == -1) {
        _focusNodes.last.requestFocus();
      } else {
        _focusNodes[nextEmpty].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0) return;
    // TODO: call POST /api/v1/auth/forgot-password again
    _startTimer();
    AppSnackbar.show(
      context,
      message: 'A new code has been sent.',
      variant: AppSnackbarVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email.isNotEmpty ? widget.email : 'your email';
    final canVerify = _enteredCode.length == _codeLength && !_isVerifying;

    return AuthShell(
      header: AuthHeaderBar(
        title: 'Verification',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      bottom: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: Semantics(
          button: true,
          enabled: _secondsRemaining == 0,
          label: _secondsRemaining == 0
              ? 'Resend code'
              : 'Resend code, available in $_secondsRemaining seconds',
          child: PressableScale(
            onTap: _secondsRemaining == 0 ? _resend : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: context.colors.textSecondary),
                ),
                Text(
                  'Resend',
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: _secondsRemaining == 0
                        ? context.colors.primaryOnSurface
                        : context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.x6),
            AuthIllustration(iconPath: 'assets/images/auth/mail.svg'),
            const SizedBox(height: AppSpacing.x6),
            Text(
              'Check Your Email',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                context,
              ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text.rich(
              TextSpan(
                style: AppTypography.bodyReading(
                  context,
                ).copyWith(color: context.colors.textSecondary),
                children: [
                  const TextSpan(text: 'We sent a 6-digit code to '),
                  TextSpan(
                    text: email,
                    style: AppTypography.bodyReading(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x6),

            // ── OTP boxes with shake animation ─────────────────
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (_, child) {
                final offset = (_shakeController.isAnimating)
                    ? (8 * (0.5 - (_shakeAnimation.value - 0.5).abs()) * 2)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < _codeLength - 1 ? AppSpacing.x2 : 0,
                    ),
                    child: _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      hasError: _hasError,
                      onChanged: (v) => _onOtpChanged(i, v),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // ── Timer ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/discovery/icons/clock.svg',
                  width: 15,
                  height: 15,
                  colorFilter: ColorFilter.mode(
                    context.colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2 - 2),
                Text(
                  _secondsRemaining > 0
                      ? 'Resend code in $_timerText'
                      : 'Code expired',
                  style: AppTypography.inputLabelSmall(context).copyWith(
                    color: _secondsRemaining > 0
                        ? context.colors.textSecondary
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x6),

            PrimaryPillButton(
              label: _isVerifying ? 'Verifying…' : 'Verify',
              onPressed: canVerify ? _verify : null,
            ),
            const SizedBox(height: AppSpacing.x6),
          ],
        ),
      ],
    );
  }
}

// ─── OTP input box ────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.headlineSmall(context).copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: hasError ? AppColors.danger : context.colors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError
              ? context.colors.errorLight
              : context.colors.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasError ? AppColors.danger : context.colors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasError ? AppColors.danger : AppColors.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
