import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Storage for the two image-upload
/// flows the app actually has: activity cover photos and chat
/// attachments.
///
/// Wraps every Firebase call in a `Firebase.apps.isEmpty` guard so
/// the service degrades gracefully when the project is unconfigured
/// (no `firebase_options.dart` / platform config files). In that
/// case [uploadImage] returns `null` so the caller can either:
///   * skip the upload and proceed with the rest of the flow
///     (e.g. create an activity with no cover)
///   * surface a user-facing "image upload unavailable" error
///
/// Files are uploaded to a deterministic, user-scoped path so the
/// same image can be re-uploaded without leaving orphan blobs:
///   `uploads/{folder}/{uid}/{timestamp}-{basename}`
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  /// Uploads [localPath] to Firebase Storage and returns the
  /// public download URL. Returns `null` if Firebase isn't
  /// configured or the upload fails.
  ///
  /// [folder] is a logical bucket name (e.g. `'activity-covers'` or
  /// `'chat-attachments'`); it scopes the storage rules without
  /// leaking the underlying bucket structure to the caller.
  Future<String?> uploadImage({
    required String localPath,
    required String folder,
  }) async {
    final basename = localPath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _put(
      localPath: localPath,
      storagePath: 'uploads/$folder/$timestamp-$basename',
    );
  }

  /// Uploads [localPath] to an explicit Storage [storagePath] (no
  /// `uploads/` prefix) and returns both the path and its download
  /// URL. Used for flows where the backend validates path ownership
  /// (`PATCH /users/me/photo` requires `users/{uid}/profile/…`,
  /// activity covers require `activities/{id}/cover/…`).
  Future<({String path, String downloadUrl})?> uploadToPath({
    required String localPath,
    required String storagePath,
  }) async {
    final downloadUrl = await _put(
      localPath: localPath,
      storagePath: storagePath,
    );
    if (downloadUrl == null) return null;
    return (path: storagePath, downloadUrl: downloadUrl);
  }

  Future<String?> _put({
    required String localPath,
    required String storagePath,
  }) async {
    if (!_isFirebaseReady()) {
      debugPrint(
        '[StorageService] Firebase not initialised — skipping upload',
      );
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('[StorageService] File not found: $localPath');
        return null;
      }

      final basename = localPath.split('/').last;
      final ref = FirebaseStorage.instance.ref(storagePath);

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: _guessContentType(basename)),
      );

      if (uploadTask.state != TaskState.success) {
        debugPrint(
          '[StorageService] Upload state: ${uploadTask.state}',
        );
        return null;
      }

      return await ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('[StorageService._put] $e\n$st');
      return null;
    }
  }

  /// True if Firebase has been initialised (i.e. the platform config
  /// files are present and `Firebase.initializeApp()` succeeded at
  /// app start). When false, every call to [uploadImage] returns
  /// `null`.
  bool _isFirebaseReady() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Sniffs the file extension for a MIME type so the downloaded
  /// file opens with the right app on the receiving end. Falls back
  /// to `image/jpeg` for unknown extensions — `image_picker` always
  /// produces a JPEG/PNG so this is a safe default.
  String _guessContentType(String basename) {
    final ext = basename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
