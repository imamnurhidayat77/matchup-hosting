import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/app_notification.dart';

// ─── UI extensions on NotificationType ───────────────────────────────────────

extension _NotifTypeUi on NotificationType {
  Color get color => switch (this) {
        NotificationType.chat => AppColors.primary,
        NotificationType.activity => AppColors.accent,
        NotificationType.system => AppColors.success,
        NotificationType.request => AppColors.warning,
        NotificationType.moderation => AppColors.error,
      };

  String get iconAsset => switch (this) {
        NotificationType.chat =>
          'assets/images/discovery/icons/message_square.svg',
        NotificationType.activity =>
          'assets/images/discovery/icons/calendar.svg',
        NotificationType.system =>
          'assets/images/discovery/icons/check_circle.svg',
        NotificationType.request =>
          'assets/images/discovery/icons/users.svg',
        NotificationType.moderation =>
          'assets/images/discovery/icons/alert_circle.svg',
      };
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _notifProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).all();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  Future<void> _markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(_notifProvider);
  }

  Future<void> _markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    ref.invalidate(_notifProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_notifProvider);
    final unreadCount = async.valueOrNull?.where((n) => n.unread).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5, AppSpacing.x3, AppSpacing.x5, AppSpacing.x2,
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: const SizedBox(
                        width: 40,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleScreen,
                    ),
                  ),
                  if (unreadCount > 0)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryDarker,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 72),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // ── Segmented tabs ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
              child: AppSegmentedControl(
                labels: const ['All', 'Unread'],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => const SkeletonList(count: 5),
                error: (_, _) => ErrorRetry(
                  message: 'Could not load notifications.',
                  onRetry: () => ref.invalidate(_notifProvider),
                ),
                data: (all) {
                  final filtered = _tab == 1
                      ? all.where((n) => n.unread).toList()
                      : all;

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/images/discovery/icons/bell.svg',
                            width: 48,
                            height: 48,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textTertiary,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tab == 1
                                ? "You're all caught up!"
                                : 'No notifications yet.',
                            style: AppTypography.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final grouped = _group(filtered);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x5, 0, AppSpacing.x5, AppSpacing.x8,
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final item = grouped[i];
                      if (item is String) {
                        // Section header
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                          child: Text(
                            item,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }
                      final notif = item as AppNotification;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                        child: _SwipeToRead(
                          key: ValueKey(notif.id),
                          onDismiss: () => _markRead(notif.id),
                          child: _NotifCard(
                            item: notif,
                            onTap: () => _markRead(notif.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a mixed list of String section headers and AppNotification items.
  List<Object> _group(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayItems = items
        .where((n) => n.createdAt.isAfter(today))
        .toList();
    final yesterdayItems = items
        .where(
          (n) =>
              n.createdAt.isAfter(yesterday) && !n.createdAt.isAfter(today),
        )
        .toList();
    final weekItems = items
        .where(
          (n) =>
              n.createdAt.isAfter(weekAgo) &&
              !n.createdAt.isAfter(yesterday),
        )
        .toList();
    final olderItems = items
        .where((n) => !n.createdAt.isAfter(weekAgo))
        .toList();

    final result = <Object>[];
    if (todayItems.isNotEmpty) {
      result.add('TODAY');
      result.addAll(todayItems);
    }
    if (yesterdayItems.isNotEmpty) {
      result.add('YESTERDAY');
      result.addAll(yesterdayItems);
    }
    if (weekItems.isNotEmpty) {
      result.add('THIS WEEK');
      result.addAll(weekItems);
    }
    if (olderItems.isNotEmpty) {
      result.add('EARLIER');
      result.addAll(olderItems);
    }
    return result;
  }
}

// ─── Swipe to mark read ───────────────────────────────────────────────────────

class _SwipeToRead extends StatelessWidget {
  const _SwipeToRead({super.key, required this.child, required this.onDismiss});
  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.x5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.done_all_rounded,
              color: AppColors.primaryDarker,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Mark read',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryDarker,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─── Notification card ────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.item, required this.onTap});
  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = item.type.color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.x3 + 2),
        decoration: BoxDecoration(
          color: item.unread ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: item.unread
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: SvgPicture.asset(
                  item.type.iconAsset,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight:
                          item.unread ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(item.createdAt),
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Unread dot
            if (item.unread)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
