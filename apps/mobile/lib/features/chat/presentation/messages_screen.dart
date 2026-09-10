import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/chat_message.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final _conversationsProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
      return ref.watch(chatRepositoryProvider).conversations();
    });

final _unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final all = await ref.watch(notificationRepositoryProvider).all();
  return all.where((n) => n.unread).length;
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
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;

    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x3,
              AppSpacing.x5,
              AppSpacing.x4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat',
                        style: AppTypography.headlineLarge(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your conversations',
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _BellButton(
                  unreadCount: unreadCount,
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
            child: _SearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // ── Conversation list ────────────────────────────────────────
          Expanded(child: _ConversationList(query: _query)),
        ],
      ),
    );
  }
}

// ─── Bell button ─────────────────────────────────────────────────────────────

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unreadCount, required this.onTap});
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: 'Notifications',
      feedback: AppTapFeedback.scale,
      onTap: onTap,
      minSize: 44,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.colors.border),
          boxShadow: AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: context.colors.textPrimary,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: context.colors.errorText,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.x4),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: context.colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.primary,
              cursorWidth: 1.5,
              style: AppTypography.bodyMedium(context).copyWith(
                color: context.colors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats, sports or matches...',
                hintStyle: AppTypography.bodyMedium(context).copyWith(
                  color: context.colors.textTertiary,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            Semantics(
              button: true,
              label: 'Clear search',
              child: PressableScale(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(width: AppSpacing.x4),
        ],
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
      loading: () => const SkeletonList(count: 4),
      error: (_, _) => ErrorRetry(
        message: 'Could not load messages.',
        onRetry: () => ref.invalidate(_conversationsProvider),
      ),
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()) ||
                        c.lastMessage.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                  )
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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            0,
            AppSpacing.x5,
            AppSpacing.x6,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: _ConversationCard(
              conversation: filtered[i],
              // `filtered[i].id` is the activity id (per the local
              // seed and the backend contract for `/conversations`).
              onTap: () => context.push('/chat/${filtered[i].id}'),
            ),
          ),
        );
      },
    );
  }
}

// ─── Conversation card ────────────────────────────────────────────────────────

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final semanticLabel = hasUnread
        ? '${conversation.name}, ${conversation.unreadCount} unread, '
              '${conversation.lastMessage}'
        : '${conversation.name}, ${conversation.lastMessage}';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              // Avatar with sport-type badge overlaid at bottom-right
              ExcludeSemantics(
                child: _AvatarWithBadge(
                  conversation: conversation,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),

              // Name + preview text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            style: AppTypography.labelField(context).copyWith(
                              fontSize: 15,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        // Timestamp
                        Text(
                          conversation.time,
                          style: AppTypography.metaSub(context).copyWith(
                            color: hasUnread
                                ? AppColors.primary
                                : context.colors.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Preview + badge row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage,
                            style: AppTypography.metaSub(context).copyWith(
                              color: hasUnread
                                  ? context.colors.textPrimary
                                  : context.colors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: AppSpacing.x2),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              style: AppTypography.badgeSport(
                                context,
                              ).copyWith(
                                color: AppColors.textOnPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar with badge ────────────────────────────────────────────────────────

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          // Main avatar — slightly rounded square for group chats,
          // circle for 1-to-1s, matching the design.
          ClipRRect(
            borderRadius: BorderRadius.circular(
              conversation.isGroup ? AppRadius.card : AppRadius.pill,
            ),
            child: AppAvatar(
              assetPath: conversation.avatarAsset,
              name: conversation.name,
              size: AppAvatarSize.lg,
            ),
          ),

          // Sport/role icon badge — bottom-right corner
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.surface,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                conversation.isGroup
                    ? Icons.groups_rounded
                    : Icons.sports_rounded,
                size: 10,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
