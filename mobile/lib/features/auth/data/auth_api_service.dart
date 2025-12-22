import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../app_user.dart';

class AuthApiService {
  final ApiClient api;
  AuthApiService(this.api);

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final resp = await api.post('/auth/login', {
      'username': username,
      'password': password,
    });

    if (resp.statusCode != 200) {
      throw Exception('Login fallo: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // token
    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String?;

    //Usuario
    final userJson = data['user'] as Map<String, dynamic>;

    // Guardar token
    await api.tokens.saveTokens(access: token, refresh: refreshToken);
    return AppUser.fromJson(userJson);
  }

  Future<void> logout() async {
    await api.tokens.clear();
  }
}
