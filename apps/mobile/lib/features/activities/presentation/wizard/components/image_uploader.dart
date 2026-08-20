import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'image_picker_modal.dart';
import '../providers/form_data_provider.dart';
import '../providers/image_upload_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

/// Cover-photo uploader widget for the create-activity wizard.
/// Shows a 16:9 gradient placeholder until an image is picked, then
/// renders the selected image with Replace/Remove controls.
class ImageUploader extends ConsumerWidget {
  const ImageUploader({super.key, this.onImageSelected});

  final VoidCallback? onImageSelected;

  static final _picker = ImagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadInfo = ref.watch(imageUploadProvider);
    final isIdle = uploadInfo.state == ImageUploadState.initial ||
        uploadInfo.state == ImageUploadState.completed;

    return GestureDetector(
      onTap: isIdle ? () => _showPicker(context, ref) : null,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Deep, dark-to-dark gradient — feels premium, not "blue box"
          gradient: uploadInfo.state == ImageUploadState.initial
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                )
              : null,
          image: uploadInfo.state == ImageUploadState.completed &&
                  uploadInfo.imageUrl != null
              ? DecorationImage(
                  image: MemoryImage(base64.decode(uploadInfo.imageUrl!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Empty state ───────────────────────────────────────────
            if (uploadInfo.state == ImageUploadState.initial)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    'Add Cover Photo',
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'JPEG · PNG · WebP  ·  max 5 MB',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

            // ── Loading ───────────────────────────────────────────────
            if (uploadInfo.state == ImageUploadState.uploading)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Processing…',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Error ─────────────────────────────────────────────────
            if (uploadInfo.state == ImageUploadState.failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 36, color: AppColors.danger),
                    const SizedBox(height: 8),
                    Text(
                      uploadInfo.errorMessage ?? 'Failed to load image.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(imageUploadProvider.notifier).reset(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),

            // ── Image controls (Replace / Remove) ─────────────────────
            if (uploadInfo.state == ImageUploadState.completed &&
                uploadInfo.imageUrl != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Row(
                  children: [
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Replace',
                      color: AppColors.primary,
                      onTap: () => _showPicker(context, ref),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      color: AppColors.danger,
                      onTap: () {
                        ref.read(imageUploadProvider.notifier).clearImage();
                        ref.read(formDataProvider.notifier).setCoverImage(null);
                      },
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

  // ── Image picker flow ───────────────────────────────────────────────────

  Future<void> _showPicker(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<ImageSourceChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImagePickerModal(),
    );

    if (choice == null || !context.mounted) return;

    final source = choice == ImageSourceChoice.gallery
        ? ImageSource.gallery
        : ImageSource.camera;

    ref.read(imageUploadProvider.notifier).setUploading(0.1);

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (file == null) {
        ref.read(imageUploadProvider.notifier).reset();
        return;
      }

      ref.read(imageUploadProvider.notifier).setUploading(0.5);

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        ref.read(imageUploadProvider.notifier).setFailed(
              'Image must be under 5 MB. Please choose a smaller file.',
            );
        return;
      }

      ref.read(imageUploadProvider.notifier).setUploading(0.9);

      final base64str = base64.encode(bytes);

      // Store in both upload provider and form data
      ref.read(imageUploadProvider.notifier).setCompleted(base64str);
      ref.read(formDataProvider.notifier).setCoverImage(base64str);

      onImageSelected?.call();
    } catch (e) {
      ref.read(imageUploadProvider.notifier).setFailed(
            'Could not load image. Please try again.',
          );
    }
  }
}

// ─── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
