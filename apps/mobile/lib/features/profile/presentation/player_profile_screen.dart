import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class PlayerProfileScreen extends StatelessWidget {
  final String playerName;

  const PlayerProfileScreen({super.key, required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        playerName[0].toUpperCase(),
                        style: AppTypography.headlineLarge.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(playerName, style: AppTypography.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Auckland, New Zealand', style: AppTypography.bodyMedium),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(value: '24', label: 'Activities'),
                          Container(width: 1, height: 40, color: AppColors.border),
                          _StatItem(value: '4.9', label: 'Rating'),
                          Container(width: 1, height: 40, color: AppColors.border),
                          _StatItem(value: '12', label: 'Friends'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'About',
                      child: Text(
                        'Passionate about team sports. Usually available on weekends and weekday evenings.',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Sports',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SportChip(sport: 'Basketball', level: 'Intermediate'),
                          _SportChip(sport: 'Tennis', level: 'Advanced'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Recent Activity',
                      child: Column(
                        children: [
                          _RecentActivityTile(
                            title: 'Sunset Basketball 5v5',
                            date: 'Aug 5, 2026',
                            result: 'Won',
                          ),
                          const Divider(),
                          _RecentActivityTile(
                            title: 'Weekend Tennis Practice',
                            date: 'Aug 2, 2026',
                            result: 'Played',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add Friend'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/chat/$playerName'),
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('Message'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.bodyMedium),
      ],
    );
  }
}

class _SportChip extends StatelessWidget {
  final String sport;
  final String level;

  const _SportChip({required this.sport, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sport, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              level,
              style: AppTypography.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  final String title;
  final String date;
  final String result;

  const _RecentActivityTile({
    required this.title,
    required this.date,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_basketball, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                Text(date, style: AppTypography.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
