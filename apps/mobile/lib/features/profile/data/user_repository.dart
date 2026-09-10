import '../domain/user_model.dart';

abstract class UserRepository {
  Future<UserModel> me();
  Future<UserModel?> byId(String id);

  /// Uploads a new profile photo from [localPath] (image_picker output),
  /// persists the download URL via `PATCH /users/me`, and returns the
  /// updated user. Throws when the upload or the patch fails.
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
  });
}
