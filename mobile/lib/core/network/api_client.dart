import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'package:mobile/env.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 10);
  final TokenStorage tokens;
  final http.Client _http;

  ApiClient({required this.tokens, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final access = await tokens.readAccess();
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (access != null && access.isNotEmpty) {
      h['Authorization'] = 'Bearer $access';
    }
    return h;
  }

  void debugPrint(String message) {
    print(message);
  }

  Uri _uri(String path) => Env.resolvedBaseUri.resolve(path);

  void _logAuthHeader(String method, Uri uri, Map<String, String> headers) {
    final authHeader = headers['Authorization'];
    final hasAuthorization = authHeader != null && authHeader.isNotEmpty;
    final bearerLength = authHeader != null && authHeader.startsWith('Bearer ')
        ? authHeader.substring(7).length
        : 0;

    debugPrint(
      '🔐 $method $uri authHeader=$hasAuthorization bearerLength=$bearerLength',
    );
  }

  Never _throwDomainError({
    required String code,
    required Uri uri,
    required Object error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '❌ API error [$code] uri=$uri type=${error.runtimeType} error=$error',
    );
    if (stackTrace != null) {
      debugPrint('stack: $stackTrace');
    }
    throw Exception(code);
  }

  Never _mapAndThrow({
    required Uri uri,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (error is TimeoutException) {
      _throwDomainError(
        code: 'network_timeout',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (error is SocketException) {
      _throwDomainError(
        code: 'network_unreachable',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (error is HandshakeException || error is TlsException) {
      _throwDomainError(
        code: 'ssl_error',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (error is http.ClientException || error is FormatException) {
      _throwDomainError(
        code: 'bad_response',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
      );
    }

    _throwDomainError(
      code: 'bad_response',
      uri: uri,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // -----------------------
  // HTTP verbs
  // -----------------------
  Future<http.Response> get(String path) async {
    final uri = _uri(path);
    final headers = await _headers();
    debugPrint('GET $uri');
    _logAuthHeader(('GET'), uri, headers);
    debugPrint('headers: $headers');
    try {
      final resp = await _http
          .get(uri, headers: headers)
          .timeout(_requestTimeout);

      debugPrint('${resp.statusCode} GET ${resp.request?.url ?? uri}');
      debugPrint('body: ${resp.body}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  Future<http.Response> post(String path, Object body) async {
    final uri = _uri(path);
    final headers = await _headers();
    debugPrint('➡️ POST $uri');
    _logAuthHeader('POST', uri, headers);
    debugPrint('➡️ headers: $headers');
    debugPrint('➡️ body: ${jsonEncode(body)}');

    try {
      final resp = await _http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);

      debugPrint('⬅️ ${resp.statusCode} POST ${resp.request?.url ?? uri}');
      debugPrint('⬅️ body: ${resp.body}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  Future<http.Response> patch(String path, Object body) async {
    final uri = _uri(path);
    final headers = await _headers();
    debugPrint('PATCH $uri');
    _logAuthHeader('PATCH', uri, headers);

    try {
      final resp = await _http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      debugPrint('${resp.statusCode} PATCH ${resp.request?.url ?? uri}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  Future<http.Response> put(String path, Object body) async {
    final uri = _uri(path);
    final headers = await _headers();
    debugPrint('PUT $uri');
    _logAuthHeader('PUT', uri, headers);

    try {
      final resp = await _http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      debugPrint('${resp.statusCode} PUT ${resp.request?.url ?? uri}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  Future<http.Response> delete(String path) async {
    final uri = _uri(path);
    final headers = await _headers();
    debugPrint('DELETE $uri');
    _logAuthHeader('DELETE', uri, headers);

    try {
      final resp = await _http
          .delete(uri, headers: headers)
          .timeout(_requestTimeout);
      debugPrint('${resp.statusCode} DELETE ${resp.request?.url ?? uri}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  Future<http.Response> getRaw(String path) async {
    final uri = _uri(path);
    // No forzamos content-type aquí
    final access = await tokens.readAccess();
    final h = <String, String>{};
    if (access != null && access.isNotEmpty) {
      h['Authorization'] = 'Bearer $access';
    }

    debugPrint('GET RAW $uri');
    _logAuthHeader('GET', uri, h);
    debugPrint('headers: $h');

    try {
      final resp = await _http.get(uri, headers: h).timeout(_requestTimeout);
      debugPrint('${resp.statusCode} GET RAW ${resp.request?.url ?? uri}');
      return resp;
    } catch (e, st) {
      _mapAndThrow(uri: uri, error: e, stackTrace: st);
    }
  }

  // -----------------------
  // Helpers opcionales
  // -----------------------

  /// Lanza Exception si el backend devolvió HTML (típico 404/500 con página).
  void throwIfHtml(http.Response resp, {String? hint}) {
    final body = resp.body.trimLeft();
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      throw Exception(
        'El backend devolvió HTML. ${hint ?? ''} HTTP ${resp.statusCode}',
      );
    }
  }

  /// Decodifica JSON y si el status no es 2xx lanza un error con mensaje del backend.
  dynamic decodeJsonOrThrow(http.Response resp, {String? hint}) {
    throwIfHtml(resp, hint: hint);
    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      throw Exception(
        'Respuesta no es JSON. ${hint ?? ''} HTTP ${resp.statusCode} Body: ${resp.body}',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'HTTP ${resp.statusCode}';
      throw Exception('${hint ?? ''}$msg');
    }

    return decoded;
  }
}
