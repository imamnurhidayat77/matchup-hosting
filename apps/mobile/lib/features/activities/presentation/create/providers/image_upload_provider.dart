import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of image upload process
enum ImageUploadState {
  initial, // No image selected
  selecting, // User is choosing image source
  cropping, // User is adjusting crop
  uploading, // Image is being uploaded/compressed
  completed, // Image uploaded successfully
  failed, // Upload failed
}

/// Information about image upload
class ImageUploadInfo {
  final ImageUploadState state;
  final String? imageUrl;
  final double uploadProgress; // 0.0 to 1.0
  final String? errorMessage;

  const ImageUploadInfo({
    this.state = ImageUploadState.initial,
    this.imageUrl,
    this.uploadProgress = 0.0,
    this.errorMessage,
  });

  ImageUploadInfo copyWith({
    ImageUploadState? state,
    String? imageUrl,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return ImageUploadInfo(
      state: state ?? this.state,
      imageUrl: imageUrl ?? this.imageUrl,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isUploading => state == ImageUploadState.uploading;
  bool get isSuccess => state == ImageUploadState.completed;
  bool get isFailed => state == ImageUploadState.failed;
  bool get hasImage => imageUrl != null;
}

/// Provider for image upload state
final imageUploadProvider =
    StateNotifierProvider<ImageUploadNotifier, ImageUploadInfo>((ref) {
      return ImageUploadNotifier();
    });

class ImageUploadNotifier extends StateNotifier<ImageUploadInfo> {
  ImageUploadNotifier() : super(const ImageUploadInfo());

  void setSelecting() {
    state = state.copyWith(state: ImageUploadState.selecting);
  }

  void setCropping() {
    state = state.copyWith(state: ImageUploadState.cropping);
  }

  void setUploading(double progress) {
    state = state.copyWith(
      state: ImageUploadState.uploading,
      uploadProgress: progress,
    );
  }

  void setCompleted(String imageUrl) {
    state = state.copyWith(
      state: ImageUploadState.completed,
      imageUrl: imageUrl,
      uploadProgress: 1.0,
    );
  }

  void setFailed(String errorMessage) {
    state = state.copyWith(
      state: ImageUploadState.failed,
      errorMessage: errorMessage,
    );
  }

  void reset() {
    state = const ImageUploadInfo();
  }

  void clearImage() {
    state = state.copyWith(
      state: ImageUploadState.initial,
      imageUrl: null,
      uploadProgress: 0.0,
    );
  }
}

/// Provider for image processing operations
final imageProcessorProvider = Provider<ImageProcessor>((ref) {
  return ImageProcessor();
});

class ImageProcessor {
  /// Validate image format
  bool isValidFormat(String mimeType) {
    return mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp';
  }

  /// Validate image file size (max 5MB)
  bool isValidSize(int fileSize) {
    return fileSize <= 5 * 1024 * 1024; // 5MB
  }

  /// Validate image dimensions (max 4096x4096)
  bool isValidDimensions(int width, int height) {
    return width <= 4096 && height <= 4096;
  }

  /// Compress image to target size
  Future<String> compressImage(String base64Image) async {
    // In a real implementation, this would:
    // 1. Decode the base64 image
    // 2. Resize if dimensions exceed limits
    // 3. Compress to JPEG with quality that targets ~500KB
    // 4. Return compressed base64 string
    return base64Image; // Placeholder - return as-is for now
  }
}
