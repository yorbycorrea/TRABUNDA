import 'dart:convert';

import '../../core/network/api_client.dart';
import 'package:mobile/data/auth/entities/app_user.dart';
import 'package:mobile/domain/auth/repositories/auth_repository.dart';
import '../../features/auth/data/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient api;
  final AuthApiService _authApi;

  AuthRepositoryImpl({required this.api, required AuthApiService authApi})
    : _authApi = authApi;

  @override
  Future<ReportOpenInfo?> checkApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final fechaValue = fecha ?? DateTime.now();
    final f = _fmtDate(fechaValue);

    // ✅ create=0 para NO crear
    final res = await api.get(
      '/reportes/apoyo-horas/open?turno=$turno&fecha=$f&create=0',
    );

    if (res.statusCode != 200) {
      throw Exception('checkApoyoHoras fallo: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final existe = data['existente'] == true;

    if (!existe) return null;

    final rep = data['reporte'] as Map<String, dynamic>;
    return ReportOpenInfo.fromJson(rep);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = await api.tokens.readAccess();
    if (token == null || token.isEmpty) {
      return null;
    }

    final resp = await api.get('/auth/me');
    if (resp.statusCode != 200) {
      await api.tokens.clear();
      return null;
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final userJson = (data['user'] ?? data) as Map<String, dynamic>;
    return AppUser.fromJson(userJson);
  }

  @override
  Future<AppUser> login({required String username, required String password}) {
    return _authApi.login(username: username, password: password);
  }

  @override
  Future<void> logout() async {
    await api.tokens.clear();
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
