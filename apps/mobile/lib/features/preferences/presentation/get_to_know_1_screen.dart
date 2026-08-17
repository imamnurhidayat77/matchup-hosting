import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _borderInput = Color(0xFFCBD5E1);

class GetToKnow1Screen extends StatefulWidget {
  const GetToKnow1Screen({super.key});

  @override
  State<GetToKnow1Screen> createState() => _GetToKnow1ScreenState();
}

class _GetToKnow1ScreenState extends State<GetToKnow1Screen> {
  int _selected = 0;
  static const _options = [
    'Stay active with new sports',
    'Build consistent workout habits',
    'Find a motivating sports community',
    'Meet new sports partners',
    'Others',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const StatusBarMock(foreground: AppColors.textPrimary),
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's your primary reason for joining MatchUp?",
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(_options.length, (i) {
                            final selected = i == _selected;
                            return Padding(
                              padding: EdgeInsets.only(bottom: i == _options.length - 1 ? 0 : 12),
                              child: _OptionPill(
                                label: _options[i],
                                selected: selected,
                                onTap: () => setState(() => _selected = i),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PrimaryPillButton(
                        label: 'Next',
                        onPressed: () => context.push('/get-to-know-2'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "LET'S GET TO KNOW YOU",
              textAlign: TextAlign.center,
              style: AppTypography.inputLabelSmall.copyWith(
                color: _primaryDarker,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : _borderInput,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}