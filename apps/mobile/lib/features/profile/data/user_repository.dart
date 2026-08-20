import '../domain/user_model.dart';

abstract class UserRepository {
  Future<UserModel> me();
  Future<UserModel?> byId(String id);
  Future<UserModel> updateProfile({String? displayName, String? bio});
}
