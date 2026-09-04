import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/secure_screen.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Receives the email address via GoRouter's [GoRouterState.extra].
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, this.email = ''});
  final String email;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with TickerProviderStateMixin, SecureScreenMixin {
  static const _codeLength = 6;

  final _controllers = List.generate(_codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isVerifying = false;
  bool _hasError = false;

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _shakeAnim = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
        email: widget.email,
        code: _enteredCode,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.push('/new-password', extra: widget.email);
    } catch (e) {
      if (!mounted) return;
      _showError();
      AppSnackbar.show(
        context,
        message: e is AuthException ? e.userMessage : 'Incorrect code. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError() {
    HapticFeedback.heavyImpact();
    setState(() => _hasError = true);
    _shakeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _hasError = false);
      for (final c in _controllers) { c.clear(); }
      _focusNodes.first.requestFocus();
    });
    AppSnackbar.show(
      context,
      message: 'Incorrect code. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  }

  void _onOtpChanged(int index, String value) {
    // Handle paste
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
    try {
      await ref.read(authRepositoryProvider).forgotPassword(
        email: widget.email,
      );
      _startTimer();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'A new code has been sent.',
        variant: AppSnackbarVariant.info,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not resend code. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email.isNotEmpty ? widget.email : 'your email';
    final canVerify = _enteredCode.length == _codeLength && !_isVerifying;
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
                      Icons.mark_email_unread_rounded,
                      size: 30,
                      color: context.colors.primaryOnSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Title + subtitle
                  Text(
                    'Check Your Email',
                    style: AppTypography.headingDisplay(context),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text.rich(
                    TextSpan(
                      style: AppTypography.bodyFormSecondary(context),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                          text: email,
                          style: AppTypography.bodyFormSecondary(context)
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),

                  // OTP boxes — centered
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) {
                      final offset = _shakeCtrl.isAnimating
                          ? 8 * (0.5 - (_shakeAnim.value - 0.5).abs()) * 2
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_codeLength, (i) => _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        hasError: _hasError,
                        onChanged: (v) => _onOtpChanged(i, v),
                      )),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Timer
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: _secondsRemaining > 0
                              ? context.colors.textSecondary
                              : context.colors.errorText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _secondsRemaining > 0
                              ? 'Resend code in $_timerText'
                              : 'Code expired',
                          style: AppTypography.metaSub(context).copyWith(
                            color: _secondsRemaining > 0
                                ? context.colors.textSecondary
                                : context.colors.errorText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // Verify button
                  PressableScale(
                    onTap: canVerify ? _verify : null,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: canVerify
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: canVerify ? AppShadows.glowPrimary : null,
                      ),
                      alignment: Alignment.center,
                      child: _isVerifying
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
                              'Verify',
                              style: AppTypography.buttonPrimary,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Resend link
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          "Didn't receive the code?",
                          style: AppTypography.bodyFormSecondary(context),
                        ),
                        Semantics(
                          button: true,
                          enabled: _secondsRemaining == 0,
                          label: 'Resend code',
                          child: PressableScale(
                            onTap: _secondsRemaining == 0 ? _resend : null,
                            child: Text(
                              'Resend',
                              style: AppTypography.bodyFormSecondary(context)
                                  .copyWith(
                                    color: _secondsRemaining == 0
                                        ? AppColors.primary
                                        : context.colors.textTertiary,
                                    fontWeight: FontWeight.w700,
                                    decoration: _secondsRemaining == 0
                                        ? TextDecoration.underline
                                        : null,
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
    );
  }
}

// ─── OTP box ──────────────────────────────────────────────────────────────────

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
    final filled = controller.text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: AppColors.primary,
        style: AppTypography.headingDisplay(context).copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: hasError ? context.colors.errorText : context.colors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError
              ? context.colors.errorLight
              : filled
                  ? context.colors.primarySoft
                  : context.colors.surfaceMuted,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide(
              color: hasError
                  ? context.colors.errorText
                  : filled
                      ? AppColors.primary
                      : context.colors.border,
              width: filled ? 2 : 1,
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
      ),
    );
  }
}
