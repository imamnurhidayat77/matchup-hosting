import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/notification_icon_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/chat_message.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final _conversationsProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
  return ref.watch(chatRepositoryProvider).conversations();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: title + bell
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x3,
                AppSpacing.x5,
                AppSpacing.x2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Messages', style: AppTypography.titleScreen),
                  ),
                  NotificationIconButton(
                    hasUnread: true,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // Search bar — always visible
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        cursorColor: AppColors.textPrimary,
                        cursorWidth: 1.5,
                        style: AppTypography.bodyReading
                            .copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search chats, sports or matches...',
                          hintStyle: AppTypography.bodyReading
                              .copyWith(color: AppColors.textTertiary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // Conversation list
            Expanded(child: _ConversationList(query: _query)),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation list ────────────────────────────────────────────────────────

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_conversationsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (_, _) => ErrorRetry(
        message: 'Could not load messages.',
        onRetry: () => ref.invalidate(_conversationsProvider),
      ),
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                .where((c) =>
                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                    c.lastMessage
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                .toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: query.isEmpty ? 'No messages yet' : 'No results',
            subtitle: query.isEmpty
                ? 'Join or create an activity to start chatting.'
                : 'No conversations match "$query".',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            color: AppColors.border,
          ),
          itemBuilder: (_, i) => _ConversationTile(
            conversation: filtered[i],
            onTap: () => context.push('/chat/${filtered[i].name}'),
          ),
        );
      },
    );
  }
}

// ─── Conversation tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Row(
          children: [
            // Avatar with unread dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  assetPath: conversation.avatarAsset,
                  name: conversation.name,
                  size: AppAvatarSize.md,
                ),
                if (hasUnread)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.x3),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name,
                    style: AppTypography.labelField.copyWith(
                      fontSize: 15,
                      fontWeight:
                          hasUnread ? FontWeight.w800 : FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conversation.lastMessage,
                    style: AppTypography.metaSub.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),

            // Time + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.time,
                  style: AppTypography.metaSub.copyWith(
                    color: hasUnread
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                    fontWeight:
                        hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                      style: AppTypography.badgeSport.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
