import 'dart:convert';
import 'package:mobile/data/auth/remote/auth_remote_data_source.dart';
import '../../core/network/api_client.dart';
import 'package:mobile/data/auth/entities/app_user.dart';
import 'package:mobile/domain/auth/repositories/auth_repository.dart';
import '../../features/auth/data/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;

  AuthRepositoryImpl({required AuthRemoteDataSource remote}) : _remote = remote;

  @override
  Future<AppUser?> getCurrentUser() async {
    final userJson = await _remote.getCurrentUser();
    if (userJson == null) {
      return null;
    }

    return AppUser.fromJson(userJson);
  }

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final userJson = await _remote.login(
      username: username,
      password: password,
    );
    return AppUser.fromJson(userJson);
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
  }
}
