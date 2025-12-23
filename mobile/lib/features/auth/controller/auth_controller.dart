import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../app_user.dart';
import '../data/auth_api_service.dart';
import '../../../core/network/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthController extends ChangeNotifier {
  final AuthApiService _authApi;
  final ApiClient _api;

  AuthController({required AuthApiService authApi, required ApiClient api})
    : _authApi = authApi,
      _api = api;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // Se inicializa la app validando si el token guardado es real
  Future<void> init() async {
    _updateState(AuthStatus.loading);
    try {
      final token = await _api.tokens.readAccess();

      if (token == null || token.isEmpty) {
        return _updateState(AuthStatus.unauthenticated);
      }

      final resp = await _api.get('/auth/me');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final userJson = (data['user'] ?? data) as Map<String, dynamic>;
        _user = AppUser.fromJson(userJson);
        _updateState(AuthStatus.authenticated);
      } else {
        await _api.tokens.clear();
        _user = null;
        _updateState(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _updateState(AuthStatus.error);
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _updateState(AuthStatus.loading);
    _errorMessage = null;

    try {
      // Nota: Asegúrate que authApi.login internamente guarde el token en _api.tokens
      final user = await _authApi.login(username: username, password: password);
      _user = user;
      _updateState(AuthStatus.authenticated);
      return true;
    } catch (e) {
      _user = null;
      _errorMessage = e.toString();
      _updateState(AuthStatus.error);
      return false;
    }
  }

  Future<void> logout() async {
    _updateState(AuthStatus.loading);
    try {
      await _authApi.logout();
    } catch (_) {
      // Ignoramos error en logout para forzar cierre local
    } finally {
      _user = null;
      _errorMessage = null;
      await _api.tokens.clear();
      _updateState(AuthStatus.unauthenticated);
    }
  }

  //  Helper para notificar cambios
  void _updateState(AuthStatus newStatus) {
    if (_status == newStatus)
      return; // Optimización: no notificar si el estado es el mismo
    _status = newStatus;
    notifyListeners();
  }
}

class AuthControllerScope extends InheritedNotifier<AuthController> {
  const AuthControllerScope({
    super.key,
    required AuthController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  // Escucha cambios(reconstruye el widget cuando notifylisteners() se llame asi mismo )

  static AuthController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AuthControllerScope>();
    assert(scope != null, 'No se encontro AuthControllerScope en el arbol');
    return scope!.notifier!;
  }

  // No escucha cambios
  static AuthController read(BuildContext context) {
    final scope =
        context
                .getElementForInheritedWidgetOfExactType<AuthControllerScope>()
                ?.widget
            as AuthControllerScope?;
    assert(scope != null, 'No se encontro AuthControllScope en el arbol');
    return scope!.notifier!;
  }
}
