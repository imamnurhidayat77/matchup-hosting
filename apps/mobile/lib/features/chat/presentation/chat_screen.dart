import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/storage/secure_token_store.dart';
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
import '../../activities/domain/activity_model.dart';
import '../../activities/domain/activity_participant.dart';
import '../../report/presentation/report_activity_sheet.dart';
import '../data/typing_repository.dart';
import '../domain/chat_message.dart';
import 'chat_attachment_sheet.dart';

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
      // New message will arrive via the RTDB / polling stream.
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
                ),
              ),
            ),
            _MatchBanner(activity: activityAsync.valueOrNull),
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
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

/// Navy lift at the top edge of the chat header gradient. Also paints the
/// status-bar strip behind it so the header bleeds edge-to-edge.
const _chatHeaderNavyTop = Color(0xFF1B2BA3);

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.activityId});
  final String title;
  final String activityId;

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
/// "You are typing…" to ourselves.
final _myUidProvider = FutureProvider<String?>((ref) async {
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
  const _MatchBanner({required this.activity});
  final ActivityModel? activity;

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
    final activity = widget.activity;
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
                // Day badge — TODAY when the game is today.
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
                    _bannerDayLabel(activity?.dateTime),
                    style: AppTypography.badgeSport(context).copyWith(
                      color: AppColors.textOnPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  activity?.location ?? 'Prospect Park Courts',
                  style: AppTypography.titleMedium(context),
                ),
                const SizedBox(height: 2),
                Text(
                  activity == null
                      ? 'Kickoff at 5:30 PM'
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
/// Null-safe: falls back to 'TODAY' to preserve the previous static UI.
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
    final async = ref.watch(_messagesStreamProvider(id));
    return async.when(
      loading: () => const SkeletonList(count: 5),
      error: (_, _) => ErrorRetry(
        message: 'Could not load messages.',
        onRetry: () => ref.invalidate(_messagesStreamProvider(id)),
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
                          imageUrl: msg.senderAvatarUrl,
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



// ─── Chat settings sheet ─────────────────────────────────────────────────────

/// Bottom sheet behind the header settings button: view the activity
/// or report it. Mute/notification toggles are out of scope (no
/// backend support) and deliberately omitted.
class _ChatSettingsSheet extends StatelessWidget {
  const _ChatSettingsSheet({
    required this.activityId,
    required this.activityTitle,
  });
  final String activityId;
  final String activityTitle;

  static Future<void> show(
    BuildContext context, {
    required String activityId,
    required String activityTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSettingsSheet(
        activityId: activityId,
        activityTitle: activityTitle,
      ),
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
          _SettingsRow(
            icon: Icons.info_outline_rounded,
            label: 'View activity details',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/activity/$activityId');
            },
          ),
          _SettingsRow(
            icon: Icons.flag_outlined,
            label: 'Report activity',
            onTap: () {
              Navigator.of(context).pop();
              ReportActivitySheet.show(
                context,
                activityId: activityId,
                activityTitle: activityTitle,
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
