import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/dark_colors.dart';
import '../utils/logger.dart';

/// True when [path] points at a remote resource rather than a bundled
/// asset. Shared by widgets that accept "asset path or URL" image
/// references (covers, avatars).
bool isRemoteImage(String? path) =>
    path != null &&
    (path.startsWith('http://') || path.startsWith('https://'));

/// Image widget that gracefully falls back to a default placeholder when the
/// requested image is missing or fails to load.
///
/// Accepts a bundled asset path (`assets/...`) or a remote URL (Firebase
/// Storage download URL from `ActivityRecord.coverImageUrl` /
/// `UserRecord.photoUrl`). Used across activity detail / list screens so
/// that a missing cover image or avatar never breaks the layout — instead
/// a neutral branded placeholder is shown.
class AssetImageWithFallback extends StatelessWidget {
  const AssetImageWithFallback({
    super.key,
    this.imagePath,
    this.memoryBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.borderRadius,
    this.placeholderColor,
    this.placeholderIcon = Icons.image_outlined,
    this.isAvatar = false,
    this.decodeWidth,
  }) : assert(
          imagePath != null || memoryBytes != null,
          'Provide either imagePath or memoryBytes',
        );

  /// Bundled asset path (e.g. `assets/...`) or remote `http(s)` URL.
  /// Null when [memoryBytes] carries the image instead.
  final String? imagePath;

  /// In-memory image bytes (e.g. a just-picked cover photo that hasn't
  /// been uploaded yet). Takes precedence over [imagePath] when set.
  final Uint8List? memoryBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  /// Defaults to `context.colors.divider` (theme-aware) when null.
  final Color? placeholderColor;
  final IconData placeholderIcon;

  /// When true, the placeholder is rendered as a circle with a person icon,
  /// which is the right default for avatar tiles.
  final bool isAvatar;

  /// Explicit decode width (logical px) for images WITHOUT a fixed layout
  /// size — e.g. a hero that fills via `StackFit.expand`. Used ONLY for
  /// the `memCacheWidth` calculation, never constrains layout. Without
  /// this (and without [width]), remote images decode at full
  /// resolution: a 2000px photo decoded for a ~350px slot.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedPlaceholderColor = placeholderColor ?? context.colors.divider;
    final placeholder = isAvatar
        ? _AvatarPlaceholder(
            size: width ?? height,
            color: resolvedPlaceholderColor,
          )
        : _CoverPlaceholder(
            width: width,
            height: height,
            color: resolvedPlaceholderColor,
            icon: placeholderIcon,
          );

    if (!isRemoteImage(imagePath)) {
      // In-memory bytes (e.g. create-flow preview) render directly with
      // no loader — same treatment as bundled assets below.
      final bytes = memoryBytes;
      if (bytes != null) {
        final image = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
        if (borderRadius != null) {
          return ClipRRect(borderRadius: borderRadius!, child: image);
        }
        return image;
      }
      // Bundled assets resolve synchronously — render directly with no
      // loader (and no animation that could perturb golden tests).
      final image = Image.asset(
        imagePath!,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: image);
      }
      return image;
    }

    // Remote: disk + memory cache, decode kecil sesuai ukuran tampil,
    // placeholder STATIS (bukan shimmer) agar 6 thumbnail tidak kedip
    // satu-satu. Shimmer hanya untuk skeleton list awal.
    //
    // memCacheWidth/Height = 2x ukuran tampil untuk retina
    // (thumbnail 72 -> 144). Jangan decode gambar 2000px untuk slot 72px.
    // [decodeWidth] covers fill-layout images (hero) yang tidak punya
    // [width] eksplisit.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null
        ? (width! * dpr).round().clamp(1, 800)
        : decodeWidth != null
            ? (decodeWidth! * dpr).round().clamp(1, 1000)
            : null;
    final cacheH =
        height != null ? (height! * dpr).round().clamp(1, 800) : null;

    final image = CachedNetworkImage(
      // Non-null here: the memory/asset branches above already returned
      // for every non-remote path.
      imageUrl: imagePath!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      // Loading pakai placeholder ber-icon yang SAMA dengan error state —
      // jangan kotak kosong. Kalau network lambat, user tetap lihat icon
      // sport yang rapi, bukan kotak abu-abu yang dikira rusak.
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) {
        logWarning('[AssetImageWithFallback] failed: $url ($error)');
        return placeholder;
      },
    );

    final withSemantics = semanticLabel != null
        ? Semantics(label: semanticLabel, image: true, child: image)
        : image;

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: withSemantics);
    }
    return withSemantics;
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.width,
    required this.height,
    required this.color,
    required this.icon,
  });

  final double? width;
  final double? height;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final h = height ?? 120;
    return Container(
      width: width,
      height: height,
      color: color,
      alignment: Alignment.center,
      child: Icon(icon, size: h * 0.3, color: context.colors.textSecondary),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size, required this.color});

  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 32;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: s * 0.6,
        color: context.colors.textSecondary,
      ),
    );
  }
}
