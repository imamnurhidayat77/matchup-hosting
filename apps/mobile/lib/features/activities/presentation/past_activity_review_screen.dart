import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';

class _Participant {
  const _Participant({
    required this.name,
    required this.avatar,
    required this.rating,
    required this.given,
  });
  final String name;
  final String avatar;
  final int rating;
  final bool given;
}

class PastActivityReviewScreen extends StatefulWidget {
  const PastActivityReviewScreen({super.key});

  @override
  State<PastActivityReviewScreen> createState() => _PastActivityReviewScreenState();
}

class _PastActivityReviewScreenState extends State<PastActivityReviewScreen> {
  int _stars = 4;
  final List<_Participant> _participants = [
    _Participant(name: 'Sarah Connor', avatar: 'sarah_c.png', rating: 5, given: true),
    _Participant(name: 'Mike Chen', avatar: 'mike_c.png', rating: 4, given: true),
    _Participant(name: 'Lisa Park', avatar: 'lisa_p.png', rating: 5, given: false),
    _Participant(name: 'James Wilson', avatar: 'james_w.png', rating: 4, given: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 20),
                    _rateActivitySection(),
                    const SizedBox(height: 20),
                    _rateParticipantsSection(),
                  ],
                ),
              ),
            ),
            _submitButton(),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Activity Review',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/discovery/sports/volleyball.png',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _badge('VOLLEYBALL', AppColors.primarySoft, AppColors.primaryDarker),
                    _badge('COMPLETED', AppColors.border, AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Morning Beach Volleyball',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Sun, Jul 26 • 8:00 AM',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: SvgPicture.asset(
                        'assets/images/discovery/icons/map_pin.svg',
                        width: 14,
                        height: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sunset Beach Court',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _rateActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate This Activity',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: SvgPicture.asset(
                      filled
                          ? 'assets/images/discovery/icons/star.svg'
                          : 'assets/images/discovery/icons/star_empty.svg',
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 80,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Share your experience...',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rateParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate Participants',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < _participants.length; i++) ...[
          _participantRow(i, isLast: i == _participants.length - 1),
        ],
      ],
    );
  }

  Widget _participantRow(int index, {required bool isLast}) {
    final p = _participants[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/discovery/avatars/${p.avatar}',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < p.rating;
                    return SizedBox(
                      width: 12,
                      height: 12,
                      child: SvgPicture.asset(
                        filled
                            ? 'assets/images/discovery/icons/star.svg'
                            : 'assets/images/discovery/icons/star_empty.svg',
                        width: 12,
                        height: 12,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _participants[index] = _Participant(
                name: p.name,
                avatar: p.avatar,
                rating: p.rating,
                given: !p.given,
              );
            }),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: p.given ? AppColors.primarySoft : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: p.given ? AppColors.primary : AppColors.border,
                ),
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: SvgPicture.asset(
                  p.given
                      ? 'assets/images/discovery/icons/thumbs_up_filled.svg'
                      : 'assets/images/discovery/icons/thumbs_up.svg',
                  width: 16,
                  height: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(45, 127, 249, 0.14),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Submit Review',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}