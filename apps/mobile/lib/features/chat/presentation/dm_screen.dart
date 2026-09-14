import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../profile/domain/user_model.dart';
import '../domain/chat_message.dart';

/// Peer profile for the avatar (best-effort — null while loading or
/// when the lookup fails; bubbles fall back to initials/no avatar).
final _peerProfileProvider = FutureProvider.autoDispose
    .family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).byId(uid);
});

/// Minimal 1-on-1 direct-message thread.
///
/// Text-only MVP: peer name header, realtime bubble list, composer.
/// Opened from player profiles (`/dm/:uid`) and from `dm_message`
/// push taps. Group-chat features (images, locations, typing) stay
/// on [ChatScreen].
class DmScreen extends ConsumerStatefulWidget {
  const DmScreen({super.key, required this.otherUid, this.peerName});

  /// The other participant's uid (route path parameter).
  final String otherUid;

  /// Display name passed via route `extra` — falls back to a generic
  /// label when absent (e.g. cold-start push taps).
  final String? peerName;

  @override
  ConsumerState<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends ConsumerState<DmScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _hasText = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Clear the badge right away (fire-and-forget); the inbox list
    // refreshes underneath via its RTDB watch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dmRepositoryProvider).markRead(widget.otherUid);
    });
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() {
        _hasText = hasText;
        if (hasText) _errorText = null;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    debugPrint('[DmScreen] send tapped (len=${text.length}, sending=$_sending)');
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _errorText = null;
    });
    _controller.clear();
    try {
      final msg = await ref
          .read(dmRepositoryProvider)
          .send(otherUid: widget.otherUid, text: text);
      debugPrint('[DmScreen] sent id=${msg.id}');
      if (!mounted) return;
      setState(() => _errorText = null);
    } catch (e) {
      debugPrint('[DmScreen] send failed: $e');
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not send. Tap send to retry.';
      });
      AppSnackbar.show(
        context,
        message: 'Could not send. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        ref.watch(dmRepositoryProvider).watchMessages(widget.otherUid);
    // Peer identity resolves in order: live profile → route extra →
    // generic fallback, so the header is correct no matter how the
    // thread was opened (profile button, inbox tap, or push deep link).
    final peer = ref.watch(_peerProfileProvider(widget.otherUid)).valueOrNull;
    final peerName = (peer?.displayName.isNotEmpty == true)
        ? peer!.displayName
        : (widget.peerName ?? 'Direct message');
    final peerPhotoUrl = peer?.avatarUrl;

    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _DmHeader(peerName: peerName, peerPhotoUrl: peerPhotoUrl),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: stream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi to start the conversation.',
                      style: AppTypography.metaSub(context),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[messages.length - 1 - i];
                    return _DmBubble(
                      message: m,
                      peerName: peerName,
                      peerPhotoUrl: peerPhotoUrl,
                    );
                  },
                );
              },
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x2,
                AppSpacing.x5,
                0,
              ),
              child: Text(
                _errorText!,
                style: AppTypography.metaSub(context).copyWith(
                  color: context.colors.errorText,
                ),
              ),
            ),
          _Composer(
            controller: _controller,
            focusNode: _focusNode,
            hasText: _hasText,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _DmHeader extends StatelessWidget {
  const _DmHeader({required this.peerName, required this.peerPhotoUrl});
  final String peerName;
  final String? peerPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x2,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
            ),
            AppAvatar(
              imageUrl: peerPhotoUrl,
              name: peerName,
              size: AppAvatarSize.sm,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                peerName,
                style: AppTypography.titleMedium(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmBubble extends StatelessWidget {
  const _DmBubble({
    required this.message,
    required this.peerName,
    required this.peerPhotoUrl,
  });
  final ChatMessage message;
  final String peerName;
  final String? peerPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        Flexible(
          flex: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: mine
                  ? null
                  : Border.all(color: context.colors.border),
            ),
            child: Text(
              message.text,
              style: AppTypography.bodyMedium(context).copyWith(
                color: mine
                    ? AppColors.textOnPrimary
                    : context.colors.textPrimary,
              ),
            ),
          ),
        ),
          Padding(
            padding: EdgeInsets.only(
              left: mine ? 0 : 4,
              right: mine ? 4 : 0,
              bottom: 2,
            ),
            child: Text(
              _dmTime(message.sentAt),
              style: AppTypography.metaSub(context).copyWith(
                fontSize: 11,
                color: context.colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
    if (mine) return bubble;
    // Peer's avatar alongside their messages (group-chat parity).
    // Falls back to initials when no photo is set.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 18),
          child: AppAvatar(
            imageUrl: peerPhotoUrl,
            name: peerName,
            size: AppAvatarSize.xs,
          ),
        ),
        Flexible(child: bubble),
      ],
    );
  }
}

/// 'h:mm a' without pulling intl in for one label.
String _dmTime(DateTime dt) {
  final h24 = dt.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m ${h24 < 12 ? 'AM' : 'PM'}';
}

/// Message composer mirroring the group chat [_InputBar]: pill field
/// + circular send button that only lights up when there is text.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = hasText && !sending;
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                cursorColor: AppColors.primary,
                cursorWidth: 1.5,
                style: AppTypography.bodyMedium(context).copyWith(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  isDense: true,
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
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Semantics(
            button: true,
            label: 'Send message',
            child: PressableScale(
              onTap: canSend ? onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend
                      ? AppColors.primary
                      : context.colors.border,
                  shape: BoxShape.circle,
                  boxShadow: canSend ? AppShadows.glowPrimary : null,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : const Icon(
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
