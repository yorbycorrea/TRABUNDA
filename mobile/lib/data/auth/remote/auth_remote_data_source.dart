import 'dart:convert';

import 'package:mobile/core/network/api_client.dart';

enum AuthLoginErrorType { network, invalidCredentials, server, unknown }

class AuthLoginException implements Exception {
  AuthLoginException({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final AuthLoginErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'AuthLoginException[$type$status]: $message';
  }
}

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
    final resp = await (() async {
      try {
        return await _api.post('/auth/login', {
          'username': username,
          'password': password,
        });
      } catch (e) {
        final raw = e.toString();
        if (raw.contains('network_timeout') ||
            raw.contains('network_unreachable') ||
            raw.contains('ssl_error')) {
          throw AuthLoginException(
            type: AuthLoginErrorType.network,
            message: 'No se pudo conectar con el servidor.',
            cause: e,
          );
        }

        throw AuthLoginException(
          type: AuthLoginErrorType.unknown,
          message: 'Error inesperado durante el login.',
          cause: e,
        );
      }
    })();
    if (resp.statusCode != 200) {
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw AuthLoginException(
          type: AuthLoginErrorType.invalidCredentials,
          message: 'Usuario o contraseña inválidos.',
          statusCode: resp.statusCode,
        );
      }

      throw AuthLoginException(
        type: AuthLoginErrorType.server,
        message: 'El servidor devolvió un error al iniciar sesión.',
        statusCode: resp.statusCode,
      );
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
