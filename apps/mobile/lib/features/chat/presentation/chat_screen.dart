import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/nav_guard.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';
import '../../activities/domain/activity_participant.dart';
import '../../report/presentation/report_activity_sheet.dart';
import '../../notifications/services/push_routing.dart' show mutedChatsKey;
import '../data/chat_repository_impl.dart' show recordChatOpened;
import '../data/typing_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_poll.dart';
import '../domain/chat_reaction.dart';
import 'chat_attachment_sheet.dart';
import 'poll_create_sheet.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Real-time message stream for [id] (the activity id).
///
/// Wraps `ChatRepository.watchMessages` in a [StreamProvider] so the chat
/// screen can `ref.watch` it and rebuild on every new message. With the
/// remote implementation, the stream is backed by Firebase RTDB
/// (`activityChats/{id}/messages`); when Firebase isn't configured, the
/// remote falls back to HTTP polling every 3 seconds.
final _messagesStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) {
      return ref.watch(chatRepositoryProvider).watchMessages(id);
    });

/// Real-time emoji reactions for [id] (the activity id), keyed by
/// message id. Watched alongside [_messagesStreamProvider] so reaction
/// chips stay in sync with the conversation.
final _reactionsStreamProvider = StreamProvider.autoDispose
    .family<MessageReactions, String>((ref, id) {
      return ref.watch(chatRepositoryProvider).watchReactions(id);
    });

/// Real-time single-choice polls for [id] (the activity id), oldest
/// first. Merged into the message timeline so polls read inline with
/// the conversation that discusses them.
final _pollsStreamProvider = StreamProvider.autoDispose
    .family<List<ChatPoll>, String>((ref, id) {
      return ref.watch(chatRepositoryProvider).watchPolls(id);
    });

/// Toggles one emoji reaction, toast on transport failure. The chips
/// update via [_reactionsStreamProvider] — no optimistic state needed
/// because the RTDB stream pushes the change straight back.
/// Backend `CHAT_ARCHIVED` rejections surface verbatim.
Future<void> _toggleReaction(
  WidgetRef ref,
  BuildContext context, {
  required String activityId,
  required String messageId,
  required String emoji,
}) async {
  try {
    final reacted = await ref.read(chatRepositoryProvider).toggleReaction(
          activityId: activityId,
          messageId: messageId,
          emoji: emoji,
        );
    if (reacted == null && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Could not save your reaction. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  } on DioException catch (e) {
    if (!context.mounted) return;
    final err = e.error;
    AppSnackbar.show(
      context,
      message: err is ApiException
          ? err.userMessage
          : 'Could not save your reaction. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'Could not save your reaction. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  }
}

/// Votes for one poll option, toast on transport failure. Results
/// update via [_pollsStreamProvider] — no optimistic state needed.
/// Backend `CHAT_ARCHIVED` rejections surface verbatim so an archived
/// thread explains itself instead of a generic failure.
Future<void> _votePoll(
  WidgetRef ref,
  BuildContext context, {
  required String activityId,
  required String pollId,
  required int optionIndex,
}) async {
  try {
    final voted = await ref.read(chatRepositoryProvider).votePoll(
          activityId: activityId,
          pollId: pollId,
          optionIndex: optionIndex,
        );
    if (voted == null && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Could not save your vote. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  } on DioException catch (e) {
    if (!context.mounted) return;
    final err = e.error;
    AppSnackbar.show(
      context,
      message: err is ApiException
          ? err.userMessage
          : 'Could not save your vote. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'Could not save your vote. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  }
}

/// Renders the repository's "uploads unavailable" signal verbatim;
/// every other photo failure keeps the generic copy.
String _photoErrorMessage(Object e) {
  const unavailable = 'Photo uploads are unavailable right now';
  if (e.toString().contains(unavailable)) return unavailable;
  return 'Could not send photo.';
}

/// Local per-chat mute (no backend support — a string list of muted
/// activity ids under [mutedChatsKey]). The foreground push banner
/// skips muted chats.
Future<bool> isChatMuted(String activityId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(mutedChatsKey)?.contains(activityId) ?? false;
  } catch (_) {
    return false;
  }
}

/// Persists a mute toggle. Never throws (safe to call unawaited).
Future<void> setChatMuted(String activityId, bool muted) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(mutedChatsKey) ?? const <String>[];
    final next = current.where((id) => id != activityId).toList();
    if (muted) next.add(activityId);
    await prefs.setStringList(mutedChatsKey, next);
  } catch (_) {}
}

/// Opens a chat sender's profile from an avatar or name tap. Guarded
/// against double-tap (duplicate page keys red-screen) and empty ids.
void _openSenderProfile(BuildContext context, String senderId) {
  final uid = senderId.trim();
  if (uid.isEmpty) return;
  NavGuard.onceFor(
    'profile-$uid',
    () => context.push('/player-profile/uid/$uid'),
  );
}

/// Fetches the activity for the chat header. Returns the full
/// [ActivityModel] (which carries the title and the participant
/// roster — both of which the header needs to render the subtitle
/// and the typing display).
final _activityProvider = FutureProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
      return ref.watch(activityRepositoryProvider).byId(id);
    });

/// Fetches the participant roster for the chat. Used to populate
/// [otherUids] for the typing display so the screen polls the right
/// uids instead of a hardcoded demo list.
final _participantsProvider = FutureProvider.autoDispose
    .family<List<ActivityParticipant>, String>((ref, activityId) {
      return ref.watch(activityRepositoryProvider).participants(activityId);
    });

/// Polls `GET /api/typing/:activityId/:uid` for every member of the
/// chat and emits the subset that's currently typing.
///
/// [otherUids] is the list of participants *excluding* the current
/// user — the chat screen filters the activity's participants down
/// before calling. The polling cadence is 2 seconds
/// (per [RemoteTypingRepository.watchTyping]).
///
/// Keyed on a record `(activityId, otherUids)` so the cache is
/// re-used when only the input list changes (typical when a new
/// participant joins).
final _typingUidsProvider = StreamProvider.autoDispose
    .family<Set<String>, ({String activityId, List<String> otherUids})>(
        (ref, args) {
  return ref.watch(typingRepositoryProvider).watchTyping(
        activityId: args.activityId,
        uids: args.otherUids,
      );
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  /// Backend activity id — the screen uses this to look up the
  /// activity (for its title and participants) and to hit every
  /// `/api/chat/{id}/...` endpoint. The route `/chat/:id` is
  /// responsible for passing the real id, not the title.
  const ChatScreen({super.key, required this.activityId});
  final String activityId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  /// Tracks whether we've already announced `_id` as "I'm typing" to
  /// the backend. Flips to `true` on first keystroke and back to
  /// `false` when we send or stop typing.
  bool _isAnnouncedTyping = false;

  /// Debounce timer for the "I'm typing" announcement. We wait 500ms
  /// after the first keystroke before POSTing — typing a one-word
  /// reply shouldn't fire a write for every letter.
  Timer? _typingDebounce;

  /// Stops the typing announcement after 3s of no further keystrokes.
  /// Mirrors the WhatsApp / iMessage pattern so the server-side
  /// typing row gets cleared even if the user backgrounds the app
  /// mid-sentence.
  Timer? _typingStopTimer;

  String get _id => widget.activityId;

  /// How long after the last keystroke to keep the typing indicator
  /// alive before automatically clearing it.
  static const Duration _typingStopAfter = Duration(seconds: 3);

  /// Debounce before announcing "I'm typing" to the backend.
  static const Duration _typingDebounceAfter = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    // Capture the typing repository before any dispose can happen —
    // `ref.read` is illegal inside `dispose()` once the element is
    // deactivated (Riverpod throws "Cannot use ref after the widget
    // was disposed").
    _typingRepo = ref.read(typingRepositoryProvider);
    _msgController.addListener(_onInputChanged);
    // Baseline for the inbox unread badge: opening the chat marks
    // everything up to now as seen (best-effort, never throws).
    unawaited(recordChatOpened(_id));
  }

  TypingRepository? _typingRepo;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _msgController.removeListener(_onInputChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    // Best-effort: clear the typing row when leaving the chat so
    // other users don't see "Sarah is typing..." stuck on forever.
    // Uses the repository captured in `initState` — never `ref`.
    final repo = _typingRepo;
    if (repo != null) {
      unawaited(repo.setTyping(activityId: _id, isTyping: false));
    }
    super.dispose();
  }

  /// Called on every keystroke. Coalesces rapid input into a single
  /// "I'm typing" announcement, and schedules an automatic stop after
  /// 3s of silence.
  void _onInputChanged() {
    final has = _msgController.text.trim().isNotEmpty;
    if (has != _hasText) {
      // Only `setState` when the visible "send button enabled" state
      // actually changes — not on every keystroke.
      setState(() => _hasText = has);
    }
    if (!has) {
      // Field emptied (either sent or backspaced) → stop the
      // announcement immediately.
      _typingDebounce?.cancel();
      _typingStopTimer?.cancel();
      if (_isAnnouncedTyping) {
        _isAnnouncedTyping = false;
        unawaited(
          ref
              .read(typingRepositoryProvider)
              .setTyping(activityId: _id, isTyping: false),
        );
      }
      return;
    }

    // Schedule a "start typing" announcement if we haven't already.
    if (!_isAnnouncedTyping) {
      _typingDebounce?.cancel();
      _typingDebounce = Timer(_typingDebounceAfter, () {
        if (!mounted) return;
        if (!_isAnnouncedTyping && _msgController.text.trim().isNotEmpty) {
          _isAnnouncedTyping = true;
          unawaited(
            ref
                .read(typingRepositoryProvider)
                .setTyping(activityId: _id, isTyping: true),
          );
        }
      });
    }

    // (Re)arm the auto-stop timer — if the user pauses for 3s, the
    // server should know they stopped.
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(_typingStopAfter, () {
      if (!mounted) return;
      if (_isAnnouncedTyping) {
        _isAnnouncedTyping = false;
        unawaited(
          ref
              .read(typingRepositoryProvider)
              .setTyping(activityId: _id, isTyping: false),
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    // Local archive guard: the backend 403s anyway, but failing fast
    // keeps the draft and explains itself without a round trip.
    final activity =
        ref.read(_activityProvider(widget.activityId)).valueOrNull;
    if (activity?.isChatArchived ?? false) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Chat is archived',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    HapticFeedback.lightImpact();
    _msgController.clear();
    // Stop the typing indicator immediately — the message itself
    // proves the user finished typing. The listener in _onInputChanged
    // will see the empty field and *also* try to clear, but the
    // repository's `setTyping` is idempotent so the duplicate write
    // is harmless.
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    if (_isAnnouncedTyping) {
      _isAnnouncedTyping = false;
      unawaited(
        ref
            .read(typingRepositoryProvider)
            .setTyping(activityId: _id, isTyping: false),
      );
    }
    try {
      await ref.read(chatRepositoryProvider).send(activityId: _id, text: text);
      // The new RTDB / polling listener will pick up the message
      // automatically — no invalidate needed.
      _scrollToBottom();
    } on DioException catch (e) {
      if (!mounted) return;
      // Restore the draft so the user doesn't lose what they typed.
      _msgController.text = text;
      final err = e.error;
      AppSnackbar.show(
        context,
        message: err is ApiException
            ? err.userMessage
            : 'Could not send message. Check your connection and try again.',
        variant: AppSnackbarVariant.error,
      );
    } catch (_) {
      if (!mounted) return;
      // Restore the draft so the user doesn't lose what they typed.
      _msgController.text = text;
      AppSnackbar.show(
        context,
        message: 'Could not send message. Check your connection and try again.',
        variant: AppSnackbarVariant.error,
      );
    }
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
        await _pickAndSendImage(ImageSource.gallery);
      case ChatAttachmentChoice.camera:
        await _pickAndSendImage(ImageSource.camera);
      case ChatAttachmentChoice.location:
        await _shareLocation();
      case ChatAttachmentChoice.poll:
        await _openPollCreateSheet();
    }
  }

  Future<void> _openPollCreateSheet() async {
    final created = await PollCreateSheet.show(context, activityId: _id);
    if (created == true && mounted) {
      AppSnackbar.show(
        context,
        message: 'Poll created. Time to vote!',
        variant: AppSnackbarVariant.success,
      );
      _scrollToBottom();
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
      // Permission denied (or no camera on the device).
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
          .read(chatRepositoryProvider)
          .sendImage(activityId: _id, imagePath: picked.path);
      // New message will arrive via the RTDB / polling stream.
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        // The "uploads unavailable" signal renders verbatim; every
        // other failure keeps the generic copy.
        message: _photoErrorMessage(e),
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _shareLocation() async {
    late final Position? position;
    try {
      position = await LocationService.instance.getCurrentLocation();
    } on LocationTimeoutException {
      // A slow fix is transient — offer a retry, not a lecture about
      // permissions.
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: "Couldn't get your location. Try again.",
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    if (!mounted) return;
    if (position == null) {
      // Permanently denied ("don't ask again") can only be fixed in
      // the OS settings — offer a shortcut there.
      final permanentlyDenied = await LocationService.instance
          .isPermissionPermanentlyDenied();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: permanentlyDenied
            ? 'Location permission is off. Enable it in Settings to share your location.'
            : 'Could not access your location. Check location '
                'permissions and try again.',
        variant: AppSnackbarVariant.error,
        actionLabel: permanentlyDenied ? 'Open Settings' : null,
        onAction: permanentlyDenied ? () => Geolocator.openAppSettings() : null,
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
      // New message will arrive via the RTDB / polling stream.
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
    // Fetch the activity once on first build to get the title for the
    // header. Subsequent rebuilds reuse the cached value; refresh
    // is automatic via Riverpod's invalidation if the user navigates
    // back to the chat.
    final activityAsync = ref.watch(_activityProvider(widget.activityId));
    final title = activityAsync.valueOrNull?.title ?? 'Chat';
    // Archived threads are read-only: the backend 403s every write,
    // so the composer/poll/vote affordances switch to an archived
    // state instead of failing on tap. `false` while loading to avoid
    // flashing the archived notice on a live thread.
    final isArchived =
        activityAsync.valueOrNull?.isChatArchived ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons on the navy header. AnnotatedRegion
      // (not a manual setSystemUIOverlayStyle call) so the previous
      // style is restored automatically when leaving this screen.
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
              // Flat navy matching the header gradient's top edge — the
              // status-bar strip blends seamlessly into the header.
              color: _chatHeaderNavyTop,
              child: SafeArea(
                bottom: false,
                child: _Header(
                  title: title,
                  activityId: widget.activityId,
                  activity: activityAsync.valueOrNull,
                ),
              ),
            ),
            _MatchBanner(
              activityAsync: activityAsync,
              onRetry: () =>
                  ref.invalidate(_activityProvider(widget.activityId)),
            ),
            Expanded(
              child: _MessageList(
                id: _id,
                scrollController: _scrollController,
                isArchived: isArchived,
              ),
            ),
            _InputBar(
              controller: _msgController,
              focusNode: _focusNode,
              hasText: _hasText,
              onSend: _send,
              onAttach: () {
                if (isArchived) {
                  AppSnackbar.show(
                    context,
                    message: 'Chat is archived',
                    variant: AppSnackbarVariant.error,
                  );
                  return;
                }
                _openAttachmentSheet();
              },
              isArchived: isArchived,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

/// Navy lift at the top edge of the chat header gradient. Also paints the
/// status-bar strip behind it so the header bleeds edge-to-edge.
const _chatHeaderNavyTop = Color(0xFF1B2BA3);

class _Header extends ConsumerWidget {
  const _Header({
    required this.title,
    required this.activityId,
    this.activity,
  });
  final String title;
  final String activityId;

  /// Viewer-context snapshot for routing "View activity details".
  /// Null while the activity is still loading — the sheet then falls
  /// back to the discover detail route.
  final ActivityModel? activity;

  /// Maps a backend uid to a friendly display name. Used by the typing
  /// indicator so "alex is typing..." reads as "Alex is typing..."
  /// rather than the raw auth uid. Populated from the participants
  /// roster; falls back to the uid for unknown senders.
  String _displayName(ActivityParticipant p) {
    final n = p.name.trim();
    if (n.isEmpty || n == p.userId) return p.userId;
    // First name only — "Alex Mercer" → "Alex"
    final first = n.split(RegExp(r'\s+')).first;
    return first.isEmpty ? n : first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Exclude self from the typing poll — no "you are typing…"
    // indicator needed. Both lists below come from memoized providers
    // (stable instances!) so the typing stream subscribes exactly once
    // — never build the uid list inline here.
    final myUid = ref.watch(_myUidProvider).valueOrNull;
    final otherUids = ref.watch(
      _chatOtherUidsProvider((activityId: activityId, myUid: myUid)),
    );
    final participants =
        ref.watch(_participantsProvider(activityId)).valueOrNull ??
            const <ActivityParticipant>[];

    // Watch the typing stream for the real participant uids.
    final typing = ref
        .watch(_typingUidsProvider(
            (activityId: activityId, otherUids: otherUids)))
        .valueOrNull ??
        const <String>{};

    // Build a uid → name lookup from the roster so we can show
    // "Alex is typing…" instead of "alex is typing…".
    final nameByUid = <String, String>{
      for (final p in participants)
        if (p.userId != myUid) p.userId: _displayName(p),
    };

    final subtitle = _buildSubtitle(typing, nameByUid, participants.length);

    // Navy header: brand gradient (same family as the splash) with two
    // translucent glow circles so it reads as one designed block — not
    // a white slab stacked on the white match banner below. Pinned
    // colors (not context.colors) on purpose: navy + white passes in
    // both light and dark mode.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_chatHeaderNavyTop, AppColors.primary],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card),
        ),
      ),
      child: Stack(
        children: [
          // Decorative glows — splash motif, no asset dependency.
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
              AppSpacing.x4,
              AppSpacing.x3,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: Row(
              children: [
                // Back button — frosted glass on navy
                _HeaderButton(
                  label: 'Back',
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 16,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: AppSpacing.x3),

                // Title + members / typing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleSheet(
                          context,
                        ).copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          style: typing.isNotEmpty
                              ? AppTypography.metaSub(context).copyWith(
                                  color: AppColors.accentLight,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                )
                              : AppTypography.metaSub(context).copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),

                // Settings button — frosted glass on navy
                _HeaderButton(
                  label: 'Chat settings',
                  icon: Icons.settings_outlined,
                  iconSize: 18,
                  onTap: () => _ChatSettingsSheet.show(
                    context,
                    activityId: activityId,
                    activityTitle: title,
                    activity: activity,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the subtitle string — either a "X is typing..." message
  /// or a static members line. Names are resolved from the roster
  /// (passed in as [nameByUid]).
  String _buildSubtitle(
    Set<String> typing,
    Map<String, String> nameByUid,
    int totalParticipants,
  ) {
    if (typing.isNotEmpty) {
      final names = typing
          .map((uid) => nameByUid[uid] ?? uid)
          .toList(growable: false);
      if (names.length == 1) return '${names.first} is typing…';
      if (names.length == 2) {
        return '${names[0]} and ${names[1]} are typing…';
      }
      return '${names.length} people are typing…';
    }
    if (totalParticipants == 0) return 'Just you';
    if (totalParticipants == 1) return 'Just you';
    if (totalParticipants == 2) {
      final first = nameByUid.values.isNotEmpty
          ? nameByUid.values.first
          : '1 other';
      return 'You and $first';
    }
    final shown = nameByUid.values.take(3).join(', ');
    final more = totalParticipants - 4; // shown 3 + me
    return more > 0
        ? '$shown, +$more others'
        : 'You, $shown';
  }
}

/// Frosted-glass square button for the navy chat header.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconSize = 18,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
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
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}

/// Resolves the current user's Firebase auth uid from secure storage.
/// Used to filter "self" out of the typing display so we don't show
/// "You are typing…" to ourselves. Watches the auth uid so an account
/// switch re-reads storage instead of leaking the previous user's uid.
final _myUidProvider = FutureProvider<String?>((ref) async {
  ref.watch(authStateProvider.select((s) => s.userId));
  return SecureTokenStore.instance.readUserId();
});

/// Memoized "other participants" uid list for the typing indicator.
///
/// Same identity-stability contract as `_rosterUidsProvider` in the
/// participants screen: `_typingUidsProvider` is a stream family keyed
/// on this list, and a freshly built list every `build` would
/// resubscribe → fetch → rebuild in an infinite loop. A plain
/// `Provider` caches until the roster or uid changes, so subscribers
/// observe one stable instance.
final _chatOtherUidsProvider = Provider.autoDispose
    .family<List<String>, ({String activityId, String? myUid})>((
      ref,
      args,
    ) {
  final roster =
      ref.watch(_participantsProvider(args.activityId)).valueOrNull ??
          const <ActivityParticipant>[];
  return roster
      .where((p) => p.userId != args.myUid)
      .map((p) => p.userId)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
});

// ─── Match banner ─────────────────────────────────────────────────────────────

/// Game-context card pinned above the message list. The **Check In**
/// button only appears inside the check-in window (30 minutes before
/// the scheduled start until the activity end) — the same policy as
/// [CheckInScreen]. A 30s ticker re-evaluates the window so the
/// button materialises while the user sits in chat.
class _MatchBanner extends StatefulWidget {
  const _MatchBanner({required this.activityAsync, required this.onRetry});
  final AsyncValue<ActivityModel?> activityAsync;
  final VoidCallback onRetry;

  /// Check-in window shared with the check-in screen: opens 30
  /// minutes before start, closes at the activity end.
  static bool checkInOpen(DateTime now, DateTime start, DateTime end) {
    return !now.isBefore(start.subtract(const Duration(minutes: 30))) &&
        !now.isAfter(end);
  }

  @override
  State<_MatchBanner> createState() => _MatchBannerState();
}

class _MatchBannerState extends State<_MatchBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activityAsync.valueOrNull;
    final hasError = widget.activityAsync.hasError;
    final inWindow = activity != null &&
        _MatchBanner.checkInOpen(
          DateTime.now(),
          activity.dateTime,
          activity.endTime,
        );
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
                // Day badge — TODAY when the game is today. Neutral while
                // the activity is loading so no fake date is shown.
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
                    activity == null ? '···' : _bannerDayLabel(activity.dateTime),
                    style: AppTypography.badgeSport(context).copyWith(
                      color: AppColors.textOnPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  activity?.location ?? 'Chat',
                  style: AppTypography.titleMedium(context),
                ),
                const SizedBox(height: 2),
                if (hasError && activity == null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not load details',
                          style: AppTypography.metaSub(context),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else
                  Text(
                    activity == null
                        ? 'Loading details…'
                        : _bannerKickoffLabel(activity.dateTime),
                    style: AppTypography.metaSub(context),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Check In button — only inside the check-in window.
          // Null check first so `activity` promotes for `.id` below.
          if (activity != null && inWindow)
            Semantics(
              button: true,
              label: 'Check in to this activity',
              child: PressableScale(
                onTap: () => context.push('/check-in/${activity.id}'),
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
                    style:
                        AppTypography.buttonPrimary.copyWith(fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 'TODAY' when [dateTime] is today, otherwise the 3-letter weekday.
String _bannerDayLabel(DateTime? dateTime) {
  if (dateTime == null) return 'TODAY';
  final now = DateTime.now();
  if (now.year == dateTime.year &&
      now.month == dateTime.month &&
      now.day == dateTime.day) {
    return 'TODAY';
  }
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[(dateTime.weekday - 1) % 7];
}

/// 'Kickoff at 5:30 PM' without pulling in intl for one label.
String _bannerKickoffLabel(DateTime dateTime) {
  final h24 = dateTime.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = dateTime.minute.toString().padLeft(2, '0');
  final ap = h24 < 12 ? 'AM' : 'PM';
  return 'Kickoff at $h:$m $ap';
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

class _PollItem extends _ListItem {
  _PollItem(
    this.poll, {
    required this.showSenderName,
    required this.isLastOfRun,
  });
  final ChatPoll poll;
  final bool showSenderName;
  final bool isLastOfRun;
}

/// One row of the unified timeline — either a message or a poll —
/// carrying the timestamp + sender used for day separators and run
/// grouping. Polls interleave chronologically so a "Play at 4 or
/// 5?" reads inline with the conversation discussing it.
class _TimelineEntry {
  _TimelineEntry({
    required this.time,
    required this.senderId,
    this.message,
    this.poll,
  });
  final DateTime time;
  final String senderId;
  final ChatMessage? message;
  final ChatPoll? poll;
}

List<_ListItem> _buildListItems(
  List<ChatMessage> messages,
  List<ChatPoll> polls, {
  required String myUid,
}) {
  final timeline = <_TimelineEntry>[
    for (final msg in messages)
      _TimelineEntry(time: msg.sentAt, senderId: msg.senderId, message: msg),
    for (final poll in polls)
      _TimelineEntry(
          time: poll.createdAt, senderId: poll.createdBy, poll: poll),
  ]..sort((a, b) => a.time.compareTo(b.time));

  final items = <_ListItem>[];
  DateTime? lastDay;

  for (var i = 0; i < timeline.length; i++) {
    final entry = timeline[i];
    final day = DateTime(entry.time.year, entry.time.month, entry.time.day);
    if (lastDay == null || day != lastDay) {
      items.add(_DaySeparatorItem(_dayLabel(day)));
      lastDay = day;
    }

    final prev = i > 0 ? timeline[i - 1] : null;
    final next = i + 1 < timeline.length ? timeline[i + 1] : null;
    final nextSameDay = next != null &&
        DateTime(next.time.year, next.time.month, next.time.day) == day;
    final prevSameDay = prev != null &&
        DateTime(prev.time.year, prev.time.month, prev.time.day) == day;

    final isFirstOfRun =
        prev == null || prev.senderId != entry.senderId || !prevSameDay;
    final isLastOfRun =
        next == null || next.senderId != entry.senderId || !nextSameDay;
    final isMine = entry.senderId == myUid && myUid.isNotEmpty;

    final message = entry.message;
    if (message != null) {
      items.add(
        _MessageItem(
          message,
          showAvatar: isLastOfRun && !message.isMine,
          showSenderName: isFirstOfRun && !message.isMine,
          isLastOfRun: isLastOfRun,
        ),
      );
    } else {
      items.add(
        _PollItem(
          entry.poll!,
          showSenderName: isFirstOfRun && !isMine,
          isLastOfRun: isLastOfRun,
        ),
      );
    }
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
  const _MessageList({
    required this.id,
    required this.scrollController,
    this.isArchived = false,
  });
  final String id;
  final ScrollController scrollController;

  /// Archived threads stay readable; voting is blocked with an
  /// explanation instead of a silent no-op or a backend round trip.
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_messagesStreamProvider(id));
    final reactions = ref.watch(_reactionsStreamProvider(id)).valueOrNull;
    final polls = ref.watch(_pollsStreamProvider(id)).valueOrNull ??
        const <ChatPoll>[];
    final myUid = ref.watch(_myUidProvider).valueOrNull ?? '';
    final roster =
        ref.watch(_participantsProvider(id)).valueOrNull ?? const [];
    final names = <String, String>{
      for (final p in roster) p.userId: p.name,
    };
    return async.when(
      loading: () => const SkeletonList(count: 5),
      error: (_, _) => ErrorRetry(
        message: 'Could not load messages.',
        onRetry: () => ref.invalidate(_messagesStreamProvider(id)),
      ),
      data: (messages) {
        if (messages.isEmpty && polls.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Say hello!',
              style: AppTypography.bodyReading(context)
                  .copyWith(color: context.colors.textSecondary),
            ),
          );
        }
        final items = _buildListItems(messages, polls, myUid: myUid);
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
              _MessageItem() => _Bubble(
                  item: item,
                  reactions:
                      reactions?[item.message.id] ?? const <String, List<String>>{},
                  myUid: myUid,
                  onReact: (emoji) {
                    if (isArchived) {
                      AppSnackbar.show(
                        context,
                        message: 'Chat is archived',
                        variant: AppSnackbarVariant.error,
                      );
                      return;
                    }
                    _toggleReaction(
                      ref,
                      context,
                      activityId: id,
                      messageId: item.message.id,
                      emoji: emoji,
                    );
                  },
                ),
              _PollItem() => _PollCard(
                  item: item,
                  creatorName: item.poll.createdBy == myUid && myUid.isNotEmpty
                      ? 'You'
                      : (names[item.poll.createdBy] ??
                          item.poll.createdBy),
                  isMine: item.poll.createdBy == myUid && myUid.isNotEmpty,
                  myUid: myUid,
                  onVote: (optionIndex) {
                    if (isArchived) {
                      AppSnackbar.show(
                        context,
                        message: 'Chat is archived',
                        variant: AppSnackbarVariant.error,
                      );
                      return;
                    }
                    _votePoll(
                      ref,
                      context,
                      activityId: id,
                      pollId: item.poll.pollId,
                      optionIndex: optionIndex,
                    );
                  },
                ),
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
  const _Bubble({
    required this.item,
    this.reactions = const <String, List<String>>{},
    this.myUid = '',
    this.onReact,
  });
  final _MessageItem item;
  final EmojiReactions reactions;
  final String myUid;
  final ValueChanged<String>? onReact;

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
          // Sender name — above first bubble of a run (others only).
          // Tappable: opens the sender's profile (same guarded push as
          // every other profile entry point — duplicate keys red-screen).
          if (item.showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: GestureDetector(
                onTap: () => _openSenderProfile(context, msg.senderId),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  msg.senderName,
                  style: AppTypography.metaSub(context).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),

          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar column (others only) — tappable to the profile.
              // Photo comes from the roster (profile photoUrl); initials
              // when the sender has none.
              if (!isMine) ...[
                SizedBox(
                  width: 36,
                  child: item.showAvatar
                      ? Semantics(
                          button: true,
                          label: 'View ${msg.senderName} profile',
                          child: GestureDetector(
                            onTap: () =>
                                _openSenderProfile(context, msg.senderId),
                            child: AppAvatar(
                              imageUrl: msg.senderAvatarUrl,
                              assetPath: msg.senderAvatarAsset,
                              name: msg.senderName,
                              size: AppAvatarSize.sm,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.x2),
              ],

              // Bubble — long-press opens the reaction picker.
              Flexible(
                child: GestureDetector(
                  onLongPress: onReact == null
                      ? null
                      : () => _ReactionPickerSheet.show(
                            context,
                            onPick: onReact!,
                          ),
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
              ),
            ],
          ),

          // Reaction chips — below the bubble, above the timestamp.
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMine ? 0 : 46,
                right: isMine ? 2 : 0,
              ),
              child: _ReactionChips(
                reactions: reactions,
                myUid: myUid,
                onToggle: onReact,
              ),
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
///
/// Photos resolve local-first: a just-sent message renders from disk via
/// [ChatMessage.imagePath]; anything parsed from the backend renders from
/// the network via [ChatMessage.imageUrl]. Tapping a photo opens the
/// full-screen viewer.
class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.msg, required this.isMine});
  final ChatMessage msg;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (msg.isImage) {
      // Defensive: isImage means an image source exists, but guard
      // anyway — a null url with no local path renders the text
      // instead of crashing on a force-unwrap.
      if (msg.imageUrl == null && msg.imagePath == null) {
        return _bubbleText(context);
      }
      return PressableScale(
        onTap: () => _ChatImageViewer.show(context, msg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _ChatImage(
            msg: msg,
            width: 200,
            height: 200,
          ),
        ),
      );
    }

    if (msg.isLocation) {
      return _LocationBubble(msg: msg, isMine: isMine);
    }

    return _bubbleText(context);
  }

  /// Plain-text bubble. Selectable so users can copy message text with
  /// the native long-press toolbar. Verified: a long-press on the text
  /// is claimed by the selection gesture, so the bubble's reaction
  /// picker (parent onLongPress) does NOT also fire — reactions stay
  /// reachable via long-press on the bubble padding around the text.
  Widget _bubbleText(BuildContext context) {
    return SelectableText(
      msg.text,
      style: AppTypography.bodyReading(context).copyWith(
        color: isMine ? AppColors.textOnPrimary : context.colors.textPrimary,
      ),
    );
  }
}

// ─── Reactions ────────────────────────────────────────────────────────────────

/// Bottom sheet behind a bubble long-press: one tap toggles that emoji
/// reaction for the current user.
class _ReactionPickerSheet extends StatelessWidget {
  const _ReactionPickerSheet({required this.onPick});
  final ValueChanged<String> onPick;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onPick,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      // Root navigator so the scrim covers the tab bar too — otherwise
      // (inside ShellRoute) the sheet docks flush on top of the tab bar
      // with no gap and the bar stays bright/interactive underneath.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      elevation: 0,
      builder: (_) => _ReactionPickerSheet(onPick: onPick),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Floating panel with a gap above the bottom edge — previously the
    // sheet sat flush (viewPadding only) and looked stuck / "kurang ke atas".
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x4,
          0,
          AppSpacing.x4,
          // 16px lift + home-indicator inset so it floats ke atas.
          AppSpacing.x4 + bottomInset,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x3,
            AppSpacing.x5,
            AppSpacing.x5,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.card,
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
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  for (final emoji in reactionEmojis)
                    PressableScale(
                      onTap: () {
                        Navigator.of(context).pop();
                        onPick(emoji);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact `emoji count` chips under a reacted bubble. Highlighted when
/// the current user reacted; tapping toggles their own reaction.
class _ReactionChips extends StatelessWidget {
  const _ReactionChips({
    required this.reactions,
    required this.myUid,
    required this.onToggle,
  });
  final EmojiReactions reactions;
  final String myUid;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final entry in reactions.entries)
          PressableScale(
            onTap:
                onToggle == null ? null : () => onToggle!(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: entry.value.contains(myUid)
                    ? context.colors.primarySoft
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: entry.value.contains(myUid)
                      ? context.colors.primaryOnSurface
                      : context.colors.border,
                ),
              ),
              child: Text(
                '${entry.key} ${entry.value.length}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Poll card ────────────────────────────────────────────────────────────────

/// Inline single-choice poll card. Options render as tappable result
/// bars (share-proportional fill, voter count, "you voted" highlight);
/// tapping an option votes, tapping it again retracts the vote.
class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.item,
    required this.creatorName,
    required this.isMine,
    required this.myUid,
    required this.onVote,
  });
  final _PollItem item;
  final String creatorName;
  final bool isMine;
  final String myUid;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final poll = item.poll;
    final myVote = poll.myVote(myUid);
    final maxW = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (item.showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: GestureDetector(
                onTap: () =>
                    _openSenderProfile(context, item.poll.createdBy),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  creatorName,
                  style: AppTypography.metaSub(context).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) const SizedBox(width: 36),
              if (!isMine) const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxW),
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: context.colors.primaryOnSurface,
                      width: 1.5,
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 14,
                            color: context.colors.primaryOnSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'POLL',
                            style: AppTypography.metaSub(context).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: context.colors.primaryOnSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        poll.question,
                        style: AppTypography.bodyMedium(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      for (var i = 0; i < poll.options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _PollOption(
                            label: poll.options[i],
                            votes: poll.votesFor(i),
                            share: poll.shareFor(i),
                            isMyVote: myVote == i,
                            onTap: () => onVote(i),
                          ),
                        ),
                      Text(
                        poll.totalVotes == 0
                            ? 'No votes yet · tap to vote'
                            : '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}'
                                '${myVote == null ? ' · tap to vote' : ' · tap again to remove vote'}',
                        style: AppTypography.metaSub(context).copyWith(
                          fontSize: 11,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.votes,
    required this.share,
    required this.isMyVote,
    required this.onTap,
  });
  final String label;
  final int votes;
  final double share;
  final bool isMyVote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share <= 0 ? 0 : share.clamp(0.06, 1.0),
              child: Container(
                height: 40,
                color: isMyVote
                    ? context.colors.primaryOnSurface.withValues(alpha: 0.35)
                    : context.colors.primarySoft,
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  if (isMyVote)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: context.colors.primaryOnSurface,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.bodyMedium(context).copyWith(
                        fontWeight:
                            isMyVote ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(share * 100).round()}%',
                    style: AppTypography.metaSub(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single chat photo — local file when the message was just captured on
/// this device, network image otherwise. Shared by the bubble and the
/// full-screen viewer so both paths stay in sync.
class _ChatImage extends StatelessWidget {
  const _ChatImage({
    required this.msg,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });
  final ChatMessage msg;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final localPath = msg.imagePath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _brokenImage(context),
      );
    }
    final remoteUrl = msg.imageUrl;
    if (remoteUrl == null) return _brokenImage(context);
    return CachedNetworkImage(
      imageUrl: remoteUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth:
          (width * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 1200),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      progressIndicatorBuilder: (context, url, progress) => Container(
        width: width,
        height: height,
        color: context.colors.surfaceMuted,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('[ChatImage] failed: $url ($error)');
        return _brokenImage(context);
      },
    );
  }

  Widget _brokenImage(BuildContext context) {
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

/// Full-screen photo viewer behind a bubble tap: pinch-to-zoom via
/// [InteractiveViewer], dark scrim, and a close button. Works for both
/// local (just-sent) and remote (received) photos.
class _ChatImageViewer extends StatelessWidget {
  const _ChatImageViewer({required this.msg});
  final ChatMessage msg;

  static Future<void> show(BuildContext context, ChatMessage msg) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _ChatImageViewer(msg: msg),
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
              minScale: 1,
              maxScale: 4,
              child: _ChatImage(
                msg: msg,
                width: screen.width,
                height: screen.height * 0.8,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 8,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Close photo',
              child: PressableScale(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
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

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.msg, required this.isMine});
  final ChatMessage msg;
  final bool isMine;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${msg.latitude},${msg.longitude}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Could not open Maps',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? AppColors.textOnPrimary : context.colors.textPrimary;
    return PressableScale(
      onTap: () => _open(context),
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
    this.isArchived = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  /// Archived threads render a read-only notice in place of the
  /// composer — history stays visible above, writes are gone.
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    if (isArchived) {
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 18,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  'Chat archived · history is read-only',
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
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



// ─── Chat settings sheet ─────────────────────────────────────────────────────

/// Route for "View activity details" from chat: the viewer is a member
/// here, so never the discover (join-flow) detail — host → manage,
/// participant → joined, past lifecycle → review. Null (still loading)
/// falls back to the discover route.
String _detailsRoute(ActivityModel? activity, String activityId) {
  if (activity == null) return '/activity/$activityId';
  if (activity.status == ActivityStatus.past) {
    return '/past-activity/$activityId/review';
  }
  if (activity.isHost) return '/manage-activity/$activityId';
  if (activity.isParticipant) return '/joined-activity/$activityId';
  return '/activity/$activityId';
}

/// Bottom sheet behind the header settings button: view the activity,
/// open its photo album, toggle the local mute, or report it.
class _ChatSettingsSheet extends StatefulWidget {
  const _ChatSettingsSheet({
    required this.activityId,
    required this.activityTitle,
    this.activity,
  });
  final String activityId;
  final String activityTitle;

  /// Viewer-context snapshot for routing "View activity details"
  /// (host → manage, participant → joined, past → review).
  final ActivityModel? activity;

  static Future<void> show(
    BuildContext context, {
    required String activityId,
    required String activityTitle,
    ActivityModel? activity,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSettingsSheet(
        activityId: activityId,
        activityTitle: activityTitle,
        activity: activity,
      ),
    );
  }

  @override
  State<_ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<_ChatSettingsSheet> {
  /// Null while the persisted value loads — the row hides until then
  /// so a stale default never flashes.
  bool? _muted;

  @override
  void initState() {
    super.initState();
    isChatMuted(widget.activityId).then((muted) {
      if (mounted) setState(() => _muted = muted);
    });
  }

  Future<void> _toggleMute() async {
    final next = !(_muted ?? false);
    setState(() => _muted = next);
    await setChatMuted(widget.activityId, next);
  }

  @override
  Widget build(BuildContext context) {
    final muted = _muted ?? false;
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
          _SettingsRow(
            icon: Icons.info_outline_rounded,
            label: 'View activity details',
            onTap: () {
              Navigator.of(context).pop();
              context.push(_detailsRoute(widget.activity, widget.activityId));
            },
          ),
          _SettingsRow(
            icon: Icons.photo_library_outlined,
            label: 'Photo moments',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/chat/${widget.activityId}/moments');
            },
          ),
          if (_muted != null)
            _SettingsRow(
              icon: muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              label: muted ? 'Unmute this chat' : 'Mute this chat',
              onTap: _toggleMute,
            ),
          _SettingsRow(
            icon: Icons.flag_outlined,
            label: 'Report activity',
            onTap: () {
              Navigator.of(context).pop();
              ReportActivitySheet.show(
                context,
                activityId: widget.activityId,
                activityTitle: widget.activityTitle,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.textPrimary),
            const SizedBox(width: AppSpacing.x4),
            Text(label, style: AppTypography.titleMedium(context)),
          ],
        ),
      ),
    );
  }
}
