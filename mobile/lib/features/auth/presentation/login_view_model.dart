import 'package:flutter/widgets.dart';
import 'package:mobile/domain/auth/login_error_mapper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({LoginErrorMapper? errorMapper})
    : _errorMapper = errorMapper ?? const LoginErrorMapper();

  final LoginErrorMapper _errorMapper;

  String _appVersion = '';

  String get appVersion => _appVersion;

  String friendlyError(String raw) => _errorMapper.friendlyMessage(raw);

  Future<void> loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = 'v${info.version}';
      notifyListeners();
    } catch (_) {
      _appVersion = '';
      notifyListeners();
    }
  }
}
