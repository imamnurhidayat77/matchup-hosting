import 'dart:convert';
import 'dart:typed_data';

/// Lightweight image validation & processing service.
///
/// Deliberately avoids the `package:image` dependency — all resizing/cropping
/// is delegated to [image_picker]'s native `maxWidth/maxHeight/imageQuality`
/// parameters where possible. Remaining operations use pure Dart.
class ImageProcessor {
  /// Maximum file size accepted (5 MB).
  static const int maxFileSize = 5 * 1024 * 1024;

  /// Maximum edge dimension in pixels.
  static const int maxDimension = 4096;

  // ── Validation ────────────────────────────────────────────────────────────

  bool isValidFormat(String mimeType) {
    return const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType);
  }

  bool isValidSize(int fileSize) => fileSize <= maxFileSize;

  bool isValidDimensions(int width, int height) =>
      width <= maxDimension && height <= maxDimension;

  /// Validate a raw byte buffer and return an error string, or null if valid.
  String? validateBytes(Uint8List bytes) {
    if (bytes.lengthInBytes > maxFileSize) {
      return 'Image must be under 5 MB. Please choose a smaller file.';
    }
    return null;
  }

  // ── Encode / decode ───────────────────────────────────────────────────────

  /// Encode raw bytes to a base-64 string.
  String encodeToBase64(Uint8List bytes) => base64.encode(bytes);

  /// Decode a base-64 string back to raw bytes.
  Uint8List decodeFromBase64(String base64Image) => base64.decode(base64Image);

  // ── Light compression (quality trim only, no resize) ─────────────────────
  /// image_picker already handles resize + JPEG quality via its own parameters
  /// (`maxWidth`, `maxHeight`, `imageQuality`). This method is a thin wrapper
  /// that returns the bytes unchanged but logs size for debugging.
  Future<Uint8List> process(Uint8List bytes, {int targetKb = 800}) async {
    // If under target size, return as-is.
    if (bytes.lengthInBytes <= targetKb * 1024) return bytes;

    // For production: integrate flutter_image_compress or pass imageQuality
    // through image_picker. For now return original bytes.
    return bytes;
  }

  // ── Base64 round-trip helpers ─────────────────────────────────────────────

  /// Process a base-64 image string and return processed base-64.
  Future<String> processBase64(String base64Image) async {
    final bytes = decodeFromBase64(base64Image);
    final processed = await process(bytes);
    return encodeToBase64(processed);
  }
}
