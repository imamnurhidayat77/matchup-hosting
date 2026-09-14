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
import '../../../core/widgets/pressable_scale.dart';
import '../../profile/domain/user_model.dart';
import '../../report/presentation/report_user_sheet.dart';
import '../domain/chat_message.dart';
import 'chat_attachment_sheet.dart';

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
      _scrollToLatest();
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

  void _scrollToLatest() {
    // ListView is reversed: offset 0 is the newest message.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openAttachmentSheet() async {
    final choice = await ChatAttachmentSheet.show(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case ChatAttachmentChoice.photo:
        await _pickAndSendImage(ImageSource.gallery);
      case ChatAttachmentChoice.camera:
        await _pickAndSendImage(ImageSource.camera);
      case ChatAttachmentChoice.location:
        await _shareLocation();
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } on PlatformException {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: source == ImageSource.camera
            ? 'Could not access the camera. Check camera permissions and try again.'
            : 'Could not access your photos. Check photo permissions and try again.',
        variant: AppSnackbarVariant.error,
      );
      return;
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not attach a photo. Please try again.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    if (picked == null || !mounted) return;
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(dmRepositoryProvider)
          .sendImage(otherUid: widget.otherUid, imagePath: picked.path);
      if (!mounted) return;
      _scrollToLatest();
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
      await ref.read(dmRepositoryProvider).sendLocation(
        otherUid: widget.otherUid,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      _scrollToLatest();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Same treatment as the group chat header: white status-bar icons
      // on navy, auto-restored when leaving this screen.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AppScaffold(
        safeAreaTop: false,
        showHomeIndicator: false,
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            Container(
              color: _dmHeaderNavyTop,
              child: SafeArea(
                bottom: false,
                child: _DmHeader(
                  peerUid: widget.otherUid,
                  peerName: peerName,
                  peerPhotoUrl: peerPhotoUrl,
                ),
              ),
            ),
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
            onAttach: _openAttachmentSheet,
          ),
        ],
      ),
      ),
    );
  }
}

/// Navy lift at the top edge of the DM header gradient — same value as
/// the group chat header so both bleed into the status bar identically.
const _dmHeaderNavyTop = Color(0xFF1B2BA3);

class _DmHeader extends StatelessWidget {
  const _DmHeader({
    required this.peerUid,
    required this.peerName,
    required this.peerPhotoUrl,
  });
  final String peerUid;
  final String peerName;
  final String? peerPhotoUrl;

  @override
  Widget build(BuildContext context) {
    // Visual parity with the group chat header: navy brand gradient,
    // glow circles, rounded bottom sheet edge, frosted back button.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dmHeaderNavyTop, AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -44,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: 140,
            bottom: -56,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x2,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  child: PressableScale(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                // White ring so the avatar reads crisply on navy.
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: AppAvatar(
                    imageUrl: peerPhotoUrl,
                    name: peerName,
                    size: AppAvatarSize.sm,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    peerName,
                    style: AppTypography.titleMedium(
                      context,
                    ).copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                // Settings — frosted glass on navy, same as group chat.
                Semantics(
                  button: true,
                  label: 'Conversation settings',
                  child: PressableScale(
                    onTap: () => _DmSettingsSheet.show(
                      context,
                      peerUid: peerUid,
                      peerName: peerName,
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet behind the DM header settings button: view the peer's
/// profile or report them. Mirrors the group chat's [_ChatSettingsSheet]
/// shape (drag handle, frosted rows) without importing it.
class _DmSettingsSheet extends StatelessWidget {
  const _DmSettingsSheet({required this.peerUid, required this.peerName});
  final String peerUid;
  final String peerName;

  static Future<void> show(
    BuildContext context, {
    required String peerUid,
    required String peerName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DmSettingsSheet(peerUid: peerUid, peerName: peerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x5 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          _DmSettingsRow(
            icon: Icons.person_outline_rounded,
            label: 'View profile',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/player-profile/$peerName');
            },
          ),
          _DmSettingsRow(
            icon: Icons.flag_outlined,
            label: 'Report $peerName',
            onTap: () {
              Navigator.of(context).pop();
              ReportUserSheet.show(
                context,
                userId: peerUid,
                userName: peerName,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DmSettingsRow extends StatelessWidget {
  const _DmSettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.colors.textSecondary),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: context.colors.textTertiary,
              ),
            ],
          ),
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
            padding: message.isImage || message.isLocation
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            child: _DmBubbleContent(message: message, isMine: mine),
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

/// Renders a DM bubble's payload — plain text by default, or a photo /
/// location attachment when the message carries one (same wire format
/// as group chat: download URL / maps link inside [ChatMessage.text]).
class _DmBubbleContent extends StatelessWidget {
  const _DmBubbleContent({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  Future<void> _openLocation() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${message.latitude},${message.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (message.isImage) {
      return PressableScale(
        onTap: () => _DmImageViewer.show(context, message),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _DmImage(message: message, width: 200, height: 200),
        ),
      );
    }

    if (message.isLocation) {
      final fg =
          isMine ? AppColors.textOnPrimary : context.colors.textPrimary;
      return PressableScale(
        onTap: _openLocation,
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

    return Text(
      message.text,
      style: AppTypography.bodyMedium(context).copyWith(
        color: isMine ? AppColors.textOnPrimary : context.colors.textPrimary,
      ),
    );
  }
}

/// Single DM photo — local file when just captured, network image
/// otherwise. Tapping opens the full-screen viewer.
class _DmImage extends StatelessWidget {
  const _DmImage({
    required this.message,
    required this.width,
    required this.height,
  });
  final ChatMessage message;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final localPath = message.imagePath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenDmImage(context),
      );
    }
    return Image.network(
      message.imageUrl!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: context.colors.surfaceMuted,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, _, _) => _brokenDmImage(context),
    );
  }

  Widget _brokenDmImage(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.colors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: context.colors.textTertiary,
      ),
    );
  }
}

/// Full-screen DM photo viewer: pinch-to-zoom, dark scrim, close button.
class _DmImageViewer extends StatelessWidget {
  const _DmImageViewer({required this.message});
  final ChatMessage message;

  static Future<void> show(BuildContext context, ChatMessage message) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _DmImageViewer(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: _DmImage(
                message: message,
                width: screen.width,
                height: screen.height * 0.7,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Close viewer',
              child: PressableScale(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 'h:mm a' without pulling intl in for one label.
String _dmTime(DateTime dt) {  final h24 = dt.hour;
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
    required this.onAttach,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

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
          // + attachment button — same circle-outline treatment as group chat.
          Semantics(
            button: true,
            label: 'Attach photo or location',
            child: PressableScale(
              onTap: onAttach,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.colors.border,
                    width: 1.5,
                  ),
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
