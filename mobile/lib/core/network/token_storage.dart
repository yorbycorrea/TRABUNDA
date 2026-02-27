import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final FlutterSecureStorage _storage;

  const TokenStorage(this._storage);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
  }

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  Future<void> clear() async {
    debugPrint('TokenStorage.clear(): deleting access token');
    await _storage.delete(key: _kAccess);
    debugPrint('TokenStorage.clear(): deleting refresh token');
    await _storage.delete(key: _kRefresh);
    debugPrint('TokenStorage.clear(): access+refresh deleted');
  }
}
