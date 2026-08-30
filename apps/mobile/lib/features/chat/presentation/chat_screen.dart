import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/chat_message.dart';
import 'chat_attachment_sheet.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _messagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) {
      return ref.watch(chatRepositoryProvider).messages(id);
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.activityTitle});
  final String activityTitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  String get _id => widget.activityTitle;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() {
      final has = _msgController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _msgController.clear();
    try {
      await ref.read(chatRepositoryProvider).send(activityId: _id, text: text);
      ref.invalidate(_messagesProvider(_id));
      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: AppDurations.base,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openAttachmentSheet() async {
    final choice = await ChatAttachmentSheet.show(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case ChatAttachmentChoice.photo:
        await _pickAndSendImage();
      case ChatAttachmentChoice.location:
        await _shareLocation();
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendImage(activityId: _id, imagePath: picked.path);
      ref.invalidate(_messagesProvider(_id));
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not send photo.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _shareLocation() async {
    final position = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;
    if (position == null) {
      AppSnackbar.show(
        context,
        message: 'Could not access your location. Check location '
            'permissions and try again.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await ref.read(chatRepositoryProvider).sendLocation(
        activityId: _id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      ref.invalidate(_messagesProvider(_id));
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not share your location.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _Header(title: widget.activityTitle),
          _MatchBanner(),
          Expanded(
            child: _MessageList(
              id: _id,
              scrollController: _scrollController,
            ),
          ),
          _InputBar(
            controller: _msgController,
            focusNode: _focusNode,
            hasText: _hasText,
            onSend: _send,
            onAttach: _openAttachmentSheet,
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: Row(
        children: [
          // Back button — rounded square
          Semantics(
            button: true,
            label: 'Back',
            child: PressableScale(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Title + members
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSheet(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Alex, Marcus, Sarah, +5 others',
                  style: AppTypography.metaSub(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Settings button — rounded square
          Semantics(
            button: true,
            label: 'Chat settings',
            child: PressableScale(
              onTap: () {},
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Match banner ─────────────────────────────────────────────────────────────

class _MatchBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODAY badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'TODAY',
                    style: AppTypography.badgeSport(context).copyWith(
                      color: AppColors.textOnPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Prospect Park Courts',
                  style: AppTypography.titleMedium(context),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kickoff at 5:30 PM',
                  style: AppTypography.metaSub(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Check In button
          Semantics(
            button: true,
            label: 'Check in to this activity',
            child: PressableScale(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.glowPrimary,
                ),
                child: Text(
                  'Check In',
                  style: AppTypography.buttonPrimary.copyWith(fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message list ─────────────────────────────────────────────────────────────

sealed class _ListItem {}

class _DaySeparatorItem extends _ListItem {
  _DaySeparatorItem(this.label);
  final String label;
}

class _MessageItem extends _ListItem {
  _MessageItem(
    this.message, {
    required this.showAvatar,
    required this.showSenderName,
    required this.isLastOfRun,
  });
  final ChatMessage message;
  final bool showAvatar;
  final bool showSenderName;
  final bool isLastOfRun;
}

List<_ListItem> _buildListItems(List<ChatMessage> messages) {
  final items = <_ListItem>[];
  DateTime? lastDay;

  for (var i = 0; i < messages.length; i++) {
    final msg = messages[i];
    final day = DateTime(msg.sentAt.year, msg.sentAt.month, msg.sentAt.day);
    if (lastDay == null || day != lastDay) {
      items.add(_DaySeparatorItem(_dayLabel(day)));
      lastDay = day;
    }

    final prev = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final nextSameDay =
        next != null &&
        DateTime(next.sentAt.year, next.sentAt.month, next.sentAt.day) == day;
    final prevSameDay =
        prev != null &&
        DateTime(prev.sentAt.year, prev.sentAt.month, prev.sentAt.day) == day;

    final isFirstOfRun =
        prev == null || prev.senderId != msg.senderId || !prevSameDay;
    final isLastOfRun =
        next == null || next.senderId != msg.senderId || !nextSameDay;

    items.add(
      _MessageItem(
        msg,
        showAvatar: isLastOfRun && !msg.isMine,
        showSenderName: isFirstOfRun && !msg.isMine,
        isLastOfRun: isLastOfRun,
      ),
    );
  }
  return items;
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${months[day.month - 1]} ${day.day}';
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.id, required this.scrollController});
  final String id;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_messagesProvider(id));
    return async.when(
      loading: () => const SkeletonList(count: 5),
      error: (_, _) => ErrorRetry(
        message: 'Could not load messages.',
        onRetry: () => ref.invalidate(_messagesProvider(id)),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Say hello!',
              style: AppTypography.bodyReading(context)
                  .copyWith(color: context.colors.textSecondary),
            ),
          );
        }
        final items = _buildListItems(messages);
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x4,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return switch (item) {
              _DaySeparatorItem() => _DaySeparator(label: item.label),
              _MessageItem() => _Bubble(item: item),
            };
          },
        );
      },
    );
  }
}

// ─── Day separator ────────────────────────────────────────────────────────────

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Center(
        child: Text(
          label,
          style: AppTypography.metaSub(context).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: context.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item});
  final _MessageItem item;

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final msg = item.message;
    final isMine = msg.isMine;
    final maxW = MediaQuery.of(context).size.width * 0.72;
    final bottomGap = item.isLastOfRun ? AppSpacing.x4 : 3.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name — above first bubble of a run (others only)
          if (item.showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Text(
                msg.senderName,
                style: AppTypography.metaSub(context).copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
            ),

          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar column (others only)
              if (!isMine) ...[
                SizedBox(
                  width: 36,
                  child: item.showAvatar
                      ? AppAvatar(
                          assetPath: msg.senderAvatarAsset,
                          name: msg.senderName,
                          size: AppAvatarSize.sm,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.x2),
              ],

              // Bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxW),
                  padding: msg.isImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x4,
                          vertical: AppSpacing.x3,
                        ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary
                        : context.colors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.lg),
                      topRight: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(
                        isMine || !item.isLastOfRun ? AppRadius.lg : 4,
                      ),
                      bottomRight: Radius.circular(
                        !isMine || !item.isLastOfRun ? AppRadius.lg : 4,
                      ),
                    ),
                    boxShadow: isMine ? null : AppShadows.card,
                  ),
                  child: _BubbleContent(msg: msg, isMine: isMine),
                ),
              ),
            ],
          ),

          // Timestamp — below last bubble of run
          if (item.isLastOfRun)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMine ? 0 : 46,
                right: isMine ? 2 : 0,
              ),
              child: Text(
                _formatTime(msg.sentAt),
                style: AppTypography.metaSub(context).copyWith(
                  fontSize: 11,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Bubble content (text / image / location) ─────────────────────────────────

/// Renders the payload inside a chat bubble — plain text by default, or a
/// photo/location attachment when the message carries one (see
/// [ChatMessage.isImage] / [ChatMessage.isLocation]).
class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.msg, required this.isMine});
  final ChatMessage msg;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (msg.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.file(
          File(msg.imagePath!),
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 200,
            height: 200,
            color: context.colors.surfaceMuted,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: context.colors.textTertiary,
            ),
          ),
        ),
      );
    }

    if (msg.isLocation) {
      return _LocationBubble(msg: msg, isMine: isMine);
    }

    return Text(
      msg.text,
      style: AppTypography.bodyReading(context).copyWith(
        color: isMine ? AppColors.textOnPrimary : context.colors.textPrimary,
      ),
    );
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.msg, required this.isMine});
  final ChatMessage msg;
  final bool isMine;

  Future<void> _open() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${msg.latitude},${msg.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? AppColors.textOnPrimary : context.colors.textPrimary;
    return PressableScale(
      onTap: _open,
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, color: fg, size: 28),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'My Location',
              style: AppTypography.labelField(context).copyWith(color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              'Tap to open in Maps',
              style: AppTypography.metaSub(context).copyWith(
                color: fg.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
    required this.onAttach,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.x4,
        right: AppSpacing.x4,
        top: AppSpacing.x3,
        bottom: AppSpacing.x3 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // + attachment button — circle outline
          Semantics(
            button: true,
            label: 'Attach',
            child: PressableScale(
              onTap: onAttach,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),

          // Text field — pill, white, no outline on focus
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                cursorColor: AppColors.primary,
                cursorWidth: 1.5,
                style: AppTypography.bodyMedium(context).copyWith(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: AppTypography.bodyMedium(context).copyWith(
                    fontSize: 15,
                    color: context.colors.textTertiary,
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
          ),
          const SizedBox(width: AppSpacing.x2),

          // Send button — solid blue circle with up-arrow
          Semantics(
            button: true,
            label: 'Send message',
            child: PressableScale(
              onTap: hasText ? onSend : null,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasText ? AppColors.primary : context.colors.border,
                  shape: BoxShape.circle,
                  boxShadow: hasText ? AppShadows.glowPrimary : null,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 22,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


