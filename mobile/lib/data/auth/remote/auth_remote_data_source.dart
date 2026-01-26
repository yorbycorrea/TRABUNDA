import 'dart:convert';

import 'package:mobile/core/network/api_client.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await _api.tokens.readAccess();
    if (token == null || token.isEmpty) {
      return null;
    }

    final resp = await _api.get('/auth/me');
    if (resp.statusCode != 200) {
      await _api.tokens.clear();
      return null;
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final userJson = (data['user'] ?? data) as Map<String, dynamic>;
    return userJson;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final resp = await _api.post('/auth/login', {
      'username': username,
      'password': password,
    });

    if (resp.statusCode != 200) {
      throw Exception('Login fallo: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String?;
    await _api.tokens.saveTokens(access: token, refresh: refreshToken);

    final userJson = data['user'] as Map<String, dynamic>;
    return userJson;
  }

  Future<void> logout() async {
    await _api.tokens.clear();
  }
}
