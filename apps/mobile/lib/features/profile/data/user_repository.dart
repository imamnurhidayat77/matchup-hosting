import '../domain/user_model.dart';

/// The backend explicitly rejected a profile update (e.g. 400/404 with a
/// structured `{ok: false, error: {message}}` envelope). Carries the
/// server's message so screens can show *why* the save failed instead of
/// a generic line — critical for diagnosing client/server mismatches.
///
/// Only thrown when a response was actually received. Unreachable
/// backends still fall through to the offline fallback path.
class ProfileUpdateException implements Exception {
  ProfileUpdateException(this.message);
  final String message;

  @override
  String toString() => 'ProfileUpdateException: $message';
}

/// Maximum profile-photo file size accepted (5 MB — mirrors
/// `isAllowedProfileImage` in storage.rules). Files larger than this
/// are rejected client-side so the UI can name the reason instead of
/// showing a generic upload failure.
const kMaxAvatarBytes = 5 * 1024 * 1024;

/// Thrown when the picked profile photo exceeds [kMaxAvatarBytes].
/// Screens catch this separately to show the size reason; every other
/// upload failure keeps the generic message.
class AvatarTooLargeException implements Exception {
  AvatarTooLargeException([this.maxBytes = kMaxAvatarBytes]);
  final int maxBytes;

  String get message {
    final mb = maxBytes ~/ (1024 * 1024);
    return 'Cannot upload image more than ${mb}MB';
  }

  @override
  String toString() => 'AvatarTooLargeException: $message';
}

abstract class UserRepository {
  Future<UserModel> me();
  Future<UserModel?> byId(String id);

  /// Uploads a new profile photo from [localPath] (image_picker output)
  /// to `users/{uid}/profile/…`, persists it via
  /// `PATCH /users/me/photo`, and returns the updated user. Throws
  /// when the upload or the patch fails.
  Future<UserModel> uploadAvatar({required String localPath});
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    int? heightCm,
    int? weightKg,
    String? goal,
    List<({String sport, String level})>? sports,
    String? joinReason,
  });
}
