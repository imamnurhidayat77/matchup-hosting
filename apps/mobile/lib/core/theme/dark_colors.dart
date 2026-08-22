import 'package:flutter/material.dart';

/// Named dark-mode colour constants. `AppColorTokens.dark` (below) and
/// `MatchUpApp._buildDarkTheme()` (`lib/app/app.dart`) both reference these
/// instead of repeating bare `Color(0x...)` literals — this is the single
/// source of truth for the dark palette (PRD Appendix E.2 / F.4: `app.dart`'s
/// 31 raw dark `ColorScheme` literals must live here as named tokens, not
/// scattered through the theme builder).
class DarkPalette {
  DarkPalette._();

  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF111827);
  static const card = Color(0xFF1F2937);
  static const border = Color(0xFF334155);
  static const shadow = Color(0x66000000);
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);
  static const iconPrimary = Color(0xFFA8B5C7);

  /// Dark-mode container for the primary brand colour — used for
  /// `ColorScheme.primaryContainer`, the selected nav-item indicator, and
  /// the selected chip fill. One value, three Material slots, deliberately
  /// consistent rather than three near-duplicates.
  static const primaryContainer = Color(0xFF1E3A8A);

  /// Dark-mode container for the accent (orange) colour.
  static const secondaryContainer = Color(0xFF7C2D12);

  /// Brand blue lightened for text-on-dark-surface use. `AppColors
  /// .primary` (#0B1F8A) is the brand blue; on a dark background that same
  /// colour would be dark-on-dark and nearly invisible. This is the
  /// dark-mode counterpart: lightened for readability, same brand hue.
  static const primaryOnDark = Color(0xFF7BAEF7);

  static const surfaceSubtle = Color(0xFF1A2333);
  static const surfaceMuted = Color(0xFF232F42);

  /// Dark-mode counterpart of `AppColors.primarySoft` — a low-alpha brand
  /// tint instead of a near-white fill, so selected/active surfaces still
  /// read as "tinted" rather than "wrong colour" against a dark background.
  static const primarySoft = Color(0xFF243357);

  static const statusSuccessBg = Color(0xFF0F2E22);
  static const errorLight = Color(0xFF4A1A1F);
  static const warningBg = Color(0xFF3A2A0D);
  static const warningLight = Color(0xFF4A3512);
  static const successBg = Color(0xFF12362A);
  static const avatarNeutral = Color(0xFF334155);
  static const accentLight = Color(0xFF4A2A12);
  static const surfaceInverse = Color(0xFF0B1220);
  static const borderInput = Color(0xFF475569);
}

/// Dark theme tokens for MatchUp. Values follow standard iOS dark
/// palette conventions; tweak as Figma dark mode spec becomes available.
///
/// Only surfaces, borders, text, and low-alpha fills live here — every field
/// genuinely needs a different value in dark mode. Saturated brand/semantic
/// colours (`AppColors.primary`, `.danger`, `.warning`, `.error`, `.success`,
/// `.accent`, status-text colours, avatar fills) stay on the static
/// `AppColors` class and are used unchanged in both themes: they're already
/// saturated enough to read correctly against either a light or dark
/// background, and duplicating them here would just be two names for the
/// same value (PRD Appendix F.4 — "keep static `AppColors` for genuinely
/// theme-invariant values only").
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.surfaceSubtle,
    required this.surfaceMuted,
    required this.surfaceInverse,
    required this.border,
    required this.borderInput,
    required this.divider,
    required this.shadow,
    required this.textPrimary,
    required this.textLabel,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.iconPrimary,
    required this.primaryLight,
    required this.primarySoft,
    required this.primaryOnSurface,
    required this.scrim,
    required this.scrimControl,
    required this.statusSuccessBg,
    required this.successBg,
    required this.errorLight,
    required this.warningBg,
    required this.warningLight,
    required this.accentLight,
    required this.avatarNeutral,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color surfaceSubtle;
  final Color surfaceMuted;
  final Color surfaceInverse;
  final Color border;
  final Color borderInput;
  final Color divider;
  final Color shadow;
  final Color textPrimary;
  final Color textLabel;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;
  final Color iconPrimary;
  final Color primaryLight;
  final Color primarySoft;

  /// Text-on-surface variant of the brand blue. Light mode uses
  /// `AppColors.primaryDarker` (darkened for 6.4:1 on white); dark mode
  /// lightens instead, since darkening further would sink into the dark
  /// background. Same brand hue, opposite adjustment direction.
  final Color primaryOnSurface;
  final Color scrim;
  final Color scrimControl;
  final Color statusSuccessBg;
  final Color successBg;
  final Color errorLight;
  final Color warningBg;
  final Color warningLight;
  final Color accentLight;
  final Color avatarNeutral;

  static const light = AppColorTokens(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF8FAFC),
    surfaceMuted: Color(0xFFF1F5F9),
    surfaceInverse: Color(0xFF1E293B),
    border: Color(0xFFE2E8F0),
    borderInput: Color(0xFFCBD5E1),
    divider: Color(0xFFE5E7EB),
    shadow: Color(0x1A000000),
    textPrimary: Color(0xFF0F172A),
    textLabel: Color(0xFF334155),
    textSecondary: Color(0xFF64748B),
    textTertiary: Color(0xFF9CA3AF),
    textOnPrimary: Color(0xFFFFFFFF),
    iconPrimary: Color(0xFF1E293B),
    primaryLight: Color(0xFFDBEAFE),
    primarySoft: Color(0xFFE6F0FF),
    primaryOnSurface: Color(0xFF145AC8),
    scrim: Color(0x660F172A),
    scrimControl: Color(0x4D0F172A),
    statusSuccessBg: Color(0xFFD1FAE5),
    successBg: Color(0xFFE1F9F1),
    errorLight: Color(0xFFFEE2E2),
    warningBg: Color(0xFFFFFBEB),
    warningLight: Color(0xFFFEF3C7),
    accentLight: Color(0xFFFFE5D0),
    avatarNeutral: Color(0xFFE2E8F0),
  );

  static const dark = AppColorTokens(
    background: DarkPalette.background,
    surface: DarkPalette.surface,
    card: DarkPalette.card,
    surfaceSubtle: DarkPalette.surfaceSubtle,
    surfaceMuted: DarkPalette.surfaceMuted,
    surfaceInverse: DarkPalette.surfaceInverse,
    border: DarkPalette.border,
    borderInput: DarkPalette.borderInput,
    divider: DarkPalette.card,
    shadow: DarkPalette.shadow,
    textPrimary: DarkPalette.textPrimary,
    textLabel: Color(0xFFCBD5E1),
    textSecondary: DarkPalette.textSecondary,
    textTertiary: DarkPalette.textTertiary,
    textOnPrimary: Color(0xFFFFFFFF),
    iconPrimary: DarkPalette.iconPrimary,
    primaryLight: DarkPalette.primaryContainer,
    primarySoft: DarkPalette.primarySoft,
    primaryOnSurface: DarkPalette.primaryOnDark,
    scrim: Color(0x99000000),
    scrimControl: Color(0x66000000),
    statusSuccessBg: DarkPalette.statusSuccessBg,
    successBg: DarkPalette.successBg,
    errorLight: DarkPalette.errorLight,
    warningBg: DarkPalette.warningBg,
    warningLight: DarkPalette.warningLight,
    accentLight: DarkPalette.accentLight,
    avatarNeutral: DarkPalette.avatarNeutral,
  );

  @override
  AppColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? surfaceSubtle,
    Color? surfaceMuted,
    Color? surfaceInverse,
    Color? border,
    Color? borderInput,
    Color? divider,
    Color? shadow,
    Color? textPrimary,
    Color? textLabel,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnPrimary,
    Color? iconPrimary,
    Color? primaryLight,
    Color? primarySoft,
    Color? primaryOnSurface,
    Color? scrim,
    Color? scrimControl,
    Color? statusSuccessBg,
    Color? successBg,
    Color? errorLight,
    Color? warningBg,
    Color? warningLight,
    Color? accentLight,
    Color? avatarNeutral,
  }) {
    return AppColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      border: border ?? this.border,
      borderInput: borderInput ?? this.borderInput,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      textPrimary: textPrimary ?? this.textPrimary,
      textLabel: textLabel ?? this.textLabel,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      primaryLight: primaryLight ?? this.primaryLight,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryOnSurface: primaryOnSurface ?? this.primaryOnSurface,
      scrim: scrim ?? this.scrim,
      scrimControl: scrimControl ?? this.scrimControl,
      statusSuccessBg: statusSuccessBg ?? this.statusSuccessBg,
      successBg: successBg ?? this.successBg,
      errorLight: errorLight ?? this.errorLight,
      warningBg: warningBg ?? this.warningBg,
      warningLight: warningLight ?? this.warningLight,
      accentLight: accentLight ?? this.accentLight,
      avatarNeutral: avatarNeutral ?? this.avatarNeutral,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderInput: Color.lerp(borderInput, other.borderInput, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textLabel: Color.lerp(textLabel, other.textLabel, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryOnSurface: Color.lerp(
        primaryOnSurface,
        other.primaryOnSurface,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      scrimControl: Color.lerp(scrimControl, other.scrimControl, t)!,
      statusSuccessBg: Color.lerp(statusSuccessBg, other.statusSuccessBg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      avatarNeutral: Color.lerp(avatarNeutral, other.avatarNeutral, t)!,
    );
  }
}

/// Convenience accessor for theme-aware tokens. Use this instead of
/// `AppColors.surface` in new code; the static `AppColors` is kept for
/// backwards compatibility with hard-coded light values.
///
/// Falls back to [AppColorTokens.light] if the current [Theme] doesn't
/// register the extension (e.g. a widget test that pumps a bare
/// `MaterialApp` without `MatchUpApp`'s `theme:`/`darkTheme:`) rather than
/// throwing — a screen should never crash just because a test harness built
/// its own minimal `ThemeData`.
extension AppColorTokensX on BuildContext {
  AppColorTokens get colors =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.light;
}
