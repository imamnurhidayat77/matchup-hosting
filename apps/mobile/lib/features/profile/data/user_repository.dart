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
