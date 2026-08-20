import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single soft-pulsing skeleton block. Wrap any [Container] shape —
/// the shimmer is a subtle opacity pulse (minimal, no gradient sweep).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

/// Skeleton mirroring the discovery activity card silhouette.
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 40, height: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 100, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SkeletonBox(width: double.infinity, height: 200, radius: 16),
          const SizedBox(height: 20),
          const SkeletonBox(width: 220, height: 18),
          const SizedBox(height: 12),
          const SkeletonBox(width: 150, height: 12),
          const SizedBox(height: 20),
          const Row(
            children: [
              SkeletonBox(width: 90, height: 28, radius: 100),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 28, radius: 100),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for list rows (notifications, participants, activities list).
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [count] [ListRowSkeleton] items as a loading placeholder for
/// any screen that shows a scrollable list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x5,
        vertical: AppSpacing.x2,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.x3),
        child: ListRowSkeleton(),
      ),
    );
  }
}
