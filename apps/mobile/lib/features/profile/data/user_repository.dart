import '../domain/user_model.dart';

abstract class UserRepository {
  Future<UserModel> me();
  Future<UserModel?> byId(String id);
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
