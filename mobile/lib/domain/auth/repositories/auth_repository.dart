import 'package:mobile/data/auth/entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login({required String username, required String password});
  Future<AppUser?> getCurrentUser();
  Future<void> logout();
}
