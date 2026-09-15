import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/chat_message.dart';

/// Photo stream for [activityId] — every message in the group chat that
/// carries a photo, oldest first. Derived from the same
/// [ChatRepository.watchMessages] stream as the chat itself, so the album
/// stays in sync with the conversation at no extra backend cost.
final _momentsStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, activityId) {
  return ref.watch(chatRepositoryProvider).watchMessages(activityId).map(
        (messages) => messages
            .where((m) =>
                m.isImage && (m.imageUrl != null || m.imagePath != null))
            .toList(),
      );
});

/// Album of every photo shared in an activity's group chat.
///
/// Photos in the chat thread scroll away fast; this screen collects them
/// into one grid so members can relive (and revisit) the memories.
/// Reached from the chat settings sheet ("Photo moments").
class PhotoMomentsScreen extends ConsumerWidget {
  const PhotoMomentsScreen({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_momentsStreamProvider(activityId));
    return async.when(
      loading: () => const AppScaffold.detail(
        title: 'Moments',
        body: SkeletonList(count: 6),
      ),
      error: (_, _) => AppScaffold.detail(
        title: 'Moments',
        body: ErrorRetry(
          message: 'Could not load photos.',
          onRetry: () => ref.invalidate(_momentsStreamProvider(activityId)),
        ),
      ),
      data: (photos) => AppScaffold.detail(
        title: photos.isEmpty ? 'Moments' : 'Moments (${photos.length})',
        body: photos.isEmpty
            ? _EmptyMoments()
            : GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.x4),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) => PressableScale(
                  onTap: () =>
                      _MomentViewer.show(context, photos: photos, index: i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: _MomentImage(msg: photos[i], fit: BoxFit.cover),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmptyMoments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.photo_library_outlined,
                size: 32,
                color: context.colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'No photos yet',
              style: AppTypography.titleMedium(context),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Photos shared in this group chat will appear here.',
              style: AppTypography.bodyMedium(context).copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single chat photo — local file when captured on this device,
/// network image otherwise. Mirrors the bubble rendering in
/// `chat_screen.dart` so both paths stay in sync.
class _MomentImage extends StatelessWidget {
  const _MomentImage({required this.msg, this.fit = BoxFit.cover});
  final ChatMessage msg;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = msg.imagePath;
    if (path != null) {
      return Image.file(File(path), fit: fit);
    }
    return Image.network(
      msg.imageUrl!,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const SkeletonBox(),
      errorBuilder: (_, _, _) => Container(
        color: context.colors.surfaceMuted,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

// ─── Full-screen viewer ─────────────────────────────────────────────────────

/// Swipeable full-screen viewer over the album, with sender + time
/// caption per photo.
class _MomentViewer extends StatefulWidget {
  const _MomentViewer({required this.photos, required this.index});
  final List<ChatMessage> photos;
  final int index;

  static Future<void> show(
    BuildContext context, {
    required List<ChatMessage> photos,
    required int index,
  }) {
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => _MomentViewer(photos: photos, index: index),
    );
  }

  @override
  State<_MomentViewer> createState() => _MomentViewerState();
}

class _MomentViewerState extends State<_MomentViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    _controller = PageController(initialPage: widget.index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _caption(ChatMessage msg) {
    final time = TimeOfDay.fromDateTime(msg.sentAt);
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${msg.senderName} · $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: _MomentImage(msg: widget.photos[i], fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _caption(widget.photos[_current]),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_current + 1} / ${widget.photos.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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
