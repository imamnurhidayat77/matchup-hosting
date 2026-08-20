import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Figma-based typography for MatchUp.
///
/// ## Line height
/// Figma uses a single ratio — **1.26** — for virtually all UI text. That is the
/// natural line height of Plus Jakarta Sans, verified across the design file:
/// `14→17.64`, `12→15.12`, `15→18.9`, `16→20.16`, `18→22.68`, `22→27.72`,
/// `11→13.86`, `13→16.38`, `20→25.2`, `24→30.24` — every one of them ÷1.26.
///
/// The ratio is loosened **only** for long-form reading copy, where Figma is
/// deliberate: activity description `14/21` (1.5), feed-card description
/// `13/20.8` (1.6), profile bio `14/20` (1.43).
///
/// ## Letter spacing
/// Plus Jakarta Sans at display sizes is designed with **negative tracking**.
/// In Figma the setting is "Auto", which for this typeface resolves to roughly
/// **-2% at headline sizes** — this is why Figma titles look tight and crisp
/// while a naive Flutter render with `letterSpacing: 0` looks airy and loose.
///
/// We approximate that with a size-based curve: [_displayTracking] returns
/// `fontSize × -0.02` for anything 18px and up, `0` for body copy, and slight
/// positive tracking for small UPPERCASE labels (badges, chips, tabs) where
/// caps otherwise touch each other visually.
///
/// Use [uiLineHeight] for UI text and [readingLineHeight] for paragraphs.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Plus Jakarta Sans';

  /// Natural line height of Plus Jakarta Sans — the Figma default for UI text.
  static const double uiLineHeight = 1.26;

  /// Looser leading for multi-line reading copy (descriptions, chat bubbles).
  static const double readingLineHeight = 1.5;

  /// Negative tracking for display/title text (18px+). At 22px this yields
  /// -0.44, at 32px -0.64, at 44px -0.88 — matching Figma's "Auto" behaviour
  /// for Plus Jakarta Sans.
  static double _displayTracking(double fontSize) => fontSize * -0.02;

  /// Positive tracking for small UPPERCASE labels — badges, chips, section
  /// headers like "MY SPORTS". Opens up the caps so they don't visually
  /// touch each other at 11–12px.
  static const double _capsTracking = 0.5;

  // ─── Display / hero ──────────────────────────────────────────────────────

  /// 44px ExtraBold — splash wordmark.
  static TextStyle get wordmarkSplash => TextStyle(
        fontFamily: fontFamily,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(44),
        height: uiLineHeight,
        color: AppColors.textOnPrimary,
      );

  /// 32px ExtraBold — celebration headings ("It's a Match!", "Spots Filled!").
  static TextStyle get headlineLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(32),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 30px ExtraBold line-height 1.25 — onboarding heading (Figma keeps 1.25).
  static TextStyle get headingOnboarding => TextStyle(
        fontFamily: fontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(30),
        height: 1.25,
        color: AppColors.textOnPrimary,
      );

  /// 28px ExtraBold — welcome / signin / signup headings.
  static TextStyle get headingDisplay => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(28),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 24px ExtraBold — recovery-flow headings, OTP digits.
  static TextStyle get headlineMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(24),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  // ─── Titles ──────────────────────────────────────────────────────────────

  /// 22px ExtraBold — screen titles and activity titles (Figma 43:224).
  static TextStyle get titleScreen => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(22),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 20px ExtraBold — sheet titles, profile name.
  static TextStyle get headlineSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(20),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 18px ExtraBold — "Create Activity", "Edit Profile" (Figma 43:293).
  static TextStyle get titleSheet => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: _displayTracking(18),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 18px SemiBold — softer 18px title.
  static TextStyle get titleLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: _displayTracking(18),
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 16px SemiBold.
  static TextStyle get titleMedium => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  // ─── Body ────────────────────────────────────────────────────────────────

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: uiLineHeight,
        color: AppColors.textLabel,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: uiLineHeight,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: uiLineHeight,
        color: AppColors.textTertiary,
      );

  /// 14px Regular, leading **1.5** — multi-line reading copy such as
  /// "About this Activity" (Figma 43:248) and chat bubbles (43:800).
  static TextStyle get bodyReading => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: readingLineHeight,
        color: AppColors.textPrimary,
      );

  /// 16px Regular line-height 1.5 — onboarding description (Figma 42:42).
  static TextStyle get bodyOnboarding => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: readingLineHeight,
        color: AppColors.textOnPrimary,
      );

  /// 15px Regular — signin/signup supporting copy.
  static TextStyle get bodyFormSecondary => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.normal,
        height: uiLineHeight,
        color: AppColors.textSecondary,
      );

  // ─── Labels & meta ───────────────────────────────────────────────────────

  /// 14px Bold — form field label (Figma 43:297).
  static TextStyle get labelField => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 14px SemiBold — Figma input label (signin/signup).
  static TextStyle get inputLabel => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
        color: AppColors.textLabel,
      );

  /// 13px SemiBold — compact input label (signup).
  static TextStyle get inputLabelSmall => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
        color: AppColors.textLabel,
      );

  /// 12px Regular — meta-row sub text (Figma 43:239).
  ///
  /// Note: Figma renders this `#0f172a`, identical to the row title, which
  /// flattens the hierarchy — and it contradicts itself on
  /// `joined-activity-detail` (74:42) where the same sub text is `#64748b`.
  /// We follow the latter: sub text must read lighter than its heading.
  static TextStyle get metaSub => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: uiLineHeight,
        color: AppColors.textSecondary,
      );

  /// 13px SemiBold in `primaryDarker` — accent counts such as
  /// "6 joined / 10 total" (Figma 43:252).
  static TextStyle get countAccent => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
        color: AppColors.primaryDarker,
      );

  /// 12px Bold — skill chip text (Figma 57:9).
  static TextStyle get chipLabel => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: _capsTracking,
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  /// 11px ExtraBold — sport tag (Figma 75:5).
  static TextStyle get badgeSport => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: _capsTracking,
        height: uiLineHeight,
        color: AppColors.primaryDarker,
      );

  /// 11px SemiBold — bottom navigation label (Figma 43:336).
  static TextStyle get tabLabel => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: uiLineHeight,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: uiLineHeight,
        color: AppColors.textTertiary,
      );

  // ─── Buttons ─────────────────────────────────────────────────────────────

  /// 16px Bold — primary pill button (Figma 43:332).
  static TextStyle get buttonPrimary => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: uiLineHeight,
        color: AppColors.textOnPrimary,
      );

  /// 15px SemiBold — social pill button.
  static TextStyle get buttonSocial => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
        color: AppColors.textPrimary,
      );

  static TextStyle get button => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: uiLineHeight,
      );
}
