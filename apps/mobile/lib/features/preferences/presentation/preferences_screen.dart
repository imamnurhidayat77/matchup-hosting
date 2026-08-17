import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _bgSurface = Color(0xFFF8FAFC);
const _textBody = Color(0xFF475569);

enum _Skill { beginner, intermediate, advanced }

class _SportItem {
  const _SportItem({
    required this.name,
    required this.icon,
    required this.selected,
    this.skill,
  });
  final String name;
  final String icon;
  final bool selected;
  final _Skill? skill;
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<_SportItem> _items = [
    _SportItem(name: 'Basketball', icon: 'circle-x.svg', selected: true, skill: _Skill.intermediate),
    _SportItem(name: 'Tennis', icon: 'circle-x.svg', selected: true, skill: _Skill.beginner),
    _SportItem(name: 'Soccer', icon: 'circle-x.svg', selected: true, skill: _Skill.advanced),
    _SportItem(name: 'Running', icon: 'activity.svg', selected: false),
    _SportItem(name: 'Swimming', icon: 'line.svg', selected: false),
    _SportItem(name: 'Cycling', icon: 'zap.svg', selected: false),
    _SportItem(name: 'Volleyball', icon: 'users.svg', selected: false),
    _SportItem(name: 'Badminton', icon: 'circle-x.svg', selected: false),
    _SportItem(name: 'Fitness', icon: 'loader.svg', selected: false),
    _SportItem(name: 'Golf', icon: 'circle-x.svg', selected: false),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'Select the sports you play and your experience level',
                      style: AppTypography.bodyMedium.copyWith(
                        color: _textBody,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _SportCard(
                        item: _items[i],
                        onToggle: () => setState(() {
                          _items[i] = _SportItem(
                            name: _items[i].name,
                            icon: _items[i].icon,
                            selected: !_items[i].selected,
                            skill: _items[i].skill ?? _Skill.beginner,
                          );
                        }),
                        onSkill: (s) => setState(() {
                          _items[i] = _SportItem(
                            name: _items[i].name,
                            icon: _items[i].icon,
                            selected: true,
                            skill: s,
                          );
                        }),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: PrimaryPillButton(
                      label: 'Complete Profile',
                      onPressed: () => context.go('/discovery'),
                    ),
                  ),
                ],
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
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 12),
          Text(
            'Choose Your Sports & Skill Level',
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.item,
    required this.onToggle,
    required this.onSkill,
  });
  final _SportItem item;
  final VoidCallback onToggle;
  final ValueChanged<_Skill> onSkill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.selected ? _primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.selected ? AppColors.primary : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: SvgPicture.asset(
                  'assets/images/discovery/icons/${item.icon}',
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: item.selected ? 'Deselect' : 'Select',
                child: GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.selected ? AppColors.primary : _bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: item.selected
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: item.selected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (item.selected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _SkillPill(
                  label: 'Beginner',
                  selected: item.skill == _Skill.beginner,
                  onTap: () => onSkill(_Skill.beginner),
                ),
                const SizedBox(width: 8),
                _SkillPill(
                  label: 'Intermediate',
                  selected: item.skill == _Skill.intermediate,
                  onTap: () => onSkill(_Skill.intermediate),
                ),
                const SizedBox(width: 8),
                _SkillPill(
                  label: 'Advanced',
                  selected: item.skill == _Skill.advanced,
                  onTap: () => onSkill(_Skill.advanced),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillPill extends StatelessWidget {
  const _SkillPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _bgSurface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : _textBody,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}