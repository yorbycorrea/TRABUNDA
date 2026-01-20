import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../../data/auth/entities/app_user.dart';
import '../data/auth_api_service.dart';
import '../../../core/network/api_client.dart';
import 'package:mobile/data/auth/entities/app_user.dart';
import 'package:mobile/domain/auth/usecases/get_current_user.dart';
import 'package:mobile/domain/auth/usecases/login.dart';
import 'package:mobile/domain/auth/usecases/logout.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthController extends ChangeNotifier {
  final GetCurrentUser _getCurrentUser;
  final Login _login;
  final Logout _logout;

  AuthController({
    required GetCurrentUser getCurrentUser,
    required Login login,
    required Logout logout,
  }) : _getCurrentUser = getCurrentUser,
       _login = login,
       _logout = logout;

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
      final currentUser = await _getCurrentUser();
      if (currentUser == null) {
        _user = null;
        _updateState(AuthStatus.unauthenticated);
        return;
      }
      _user = currentUser;
      _updateState((AuthStatus.authenticated));
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
      final user = await _login(username: username, password: password);
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
      await _logout();
    } catch (_) {
      // Ignoramos error en logout para forzar cierre local
    } finally {
      _user = null;
      _errorMessage = null;

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
