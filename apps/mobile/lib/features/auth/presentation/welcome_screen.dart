import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pressable_scale.dart';

void _showComingSoon(BuildContext context) {
  AppSnackbar.show(
    context,
    message: 'Social sign-in coming soon.',
    variant: AppSnackbarVariant.info,
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Collage occupies ~44% of screen height (measured from the design mock).
    final collageHeight = size.height * 0.44;

    return Scaffold(
      backgroundColor: AppColors.textOnPrimary,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x4,
          topPad + AppSpacing.x2,
          AppSpacing.x4,
          bottomPad + AppSpacing.x2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Collage ────────────────────────────────────────
            _Collage(height: collageHeight),
            const SizedBox(height: AppSpacing.x5),

            // ── Title + subtitle ───────────────────────────────
            Text(
              'Welcome to MatchUp',
              textAlign: TextAlign.center,
              style: AppTypography.headingDisplay(context).copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Your social app for all things sports',
              textAlign: TextAlign.center,
              style: AppTypography.bodyFormSecondary(context),
            ),

            // Remaining space is split evenly above the button stack and
            // below the sign-in link, matching the mock's balance.
            const Spacer(),

            // ── Sign up with email ─────────────────────────────
            _PillButton(
              label: 'Sign up with email',
              onTap: () => context.go('/register'),
              bgColor: AppColors.primary,
              textColor: AppColors.textOnPrimary,
            ),
            const SizedBox(height: AppSpacing.x3),

            // ── Sign up with Apple ─────────────────────────────
            _PillButton(
              label: 'Sign up with Apple',
              onTap: () => _showComingSoon(context),
              bgColor: const Color(0xFF000000),
              textColor: AppColors.textOnPrimary,
              icon: Icons.apple_rounded,
            ),
            const SizedBox(height: AppSpacing.x3),

            // ── Sign up with Google ────────────────────────────
            _PillButton(
              label: 'Sign up with Google',
              onTap: () => _showComingSoon(context),
              bgColor: AppColors.textOnPrimary,
              textColor: const Color(0xFF1F2937),
              icon: Icons.circle_outlined,
              outlined: true,
            ),
            const SizedBox(height: AppSpacing.x5),

            // ── Already have an account? ───────────────────────
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    'Already have an account?',
                    style: AppTypography.bodyFormSecondary(context),
                  ),
                  Semantics(
                    button: true,
                    label: 'Sign in',
                    child: PressableScale(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Sign In',
                        style: AppTypography.bodyFormSecondary(context)
                            .copyWith(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ─── Collage ──────────────────────────────────────────────────────────────────
//
// Fixed pixel heights matching design proportions:
//   Left col:  top=192  bottom=130  total=328 (gap=6 → 192+6+130=328)
//   Right col: top=130  bottom=192  total=328
//   Green dot at exact center of 4-tile gap intersection

class _Collage extends StatelessWidget {
  const _Collage({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    // Fractions measured directly from the design mock (total = right col):
    //   left  top 51.5% · gap · left  bottom 38.5%  → left total  94%
    //   right top 40.0% · gap · right bottom 56.5%  → right total 100%
    // The two columns deliberately end at different Y — left stops higher.
    const gap = 14.0;
    final totalWidth = MediaQuery.of(context).size.width - AppSpacing.x4 * 2;
    final colWidth = (totalWidth - gap) / 2;

    final leftTopH = height * 0.515;
    final leftBotH = height * 0.385;

    // The right column starts slightly lower than the left, as in the mock.
    final rightOffsetTop = height * 0.055;
    final rightTopH = height * 0.375;
    final rightBotH = height - rightOffsetTop - rightTopH - gap;

    // Dot sits in the left column's horizontal gap, centred on the
    // vertical gap between the two columns.
    const dotSize = 18.0;
    final dotY = leftTopH + gap / 2 - dotSize / 2;
    final dotX = colWidth + gap / 2 - dotSize / 2;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column — shorter total
              SizedBox(
                width: colWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tile('assets/images/welcome/img_1.png', leftTopH),
                    SizedBox(height: gap),
                    _Tile('assets/images/welcome/img_2.png', leftBotH),
                  ],
                ),
              ),
              SizedBox(width: gap),
              // Right column — taller total
              SizedBox(
                width: colWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: rightOffsetTop),
                    _Tile('assets/images/welcome/img_3.png', rightTopH),
                    SizedBox(height: gap),
                    _Tile('assets/images/welcome/img_4.png', rightBotH),
                  ],
                ),
              ),
            ],
          ),

          // Green dot — at left col's gap, centered on vertical gap
          Positioned(
            top: dotY,
            left: dotX,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textOnPrimary,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4022C55E),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.path, this.tileHeight);
  final String path;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: tileHeight,
        width: double.infinity,
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          semanticLabel: 'MatchUp sport photo',
          errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9)),
        ),
      ),
    );
  }
}

// ─── Pill button ──────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.textColor,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: outlined
                ? Border.all(color: const Color(0xFFE5E7EB), width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: AppSpacing.x2),
              ],
              Text(
                label,
                style: AppTypography.buttonPrimary.copyWith(
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
