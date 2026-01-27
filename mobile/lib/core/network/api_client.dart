import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'package:mobile/env.dart';

class ApiClient {
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

  Uri _uri(String path) => Uri.parse('$Env.baseUrl$path');

  // -----------------------
  // HTTP verbs
  // -----------------------
  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$Env.baseUrl$path');
    final heders = await _headers();
    debugPrint('GET $uri');
    debugPrint('headers: $heders');

    final resp = await _http.get(uri, headers: heders);

    debugPrint('${resp.statusCode} GET $uri');
    debugPrint('body: ${resp.body}');
    return resp;

    //return _http.get(_uri(path), headers: await _headers());
  }

  Future<http.Response> post(String path, Object body) async {
    final uri = Uri.parse('$Env.baseUrl$path');
    final headers = await _headers();
    debugPrint('➡️ POST $uri');
    debugPrint('➡️ headers: $headers');
    debugPrint('➡️ body: ${jsonEncode(body)}');

    final resp = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint('⬅️ ${resp.statusCode} POST $uri');
    debugPrint('⬅️ body: ${resp.body}');
    return resp;
    //return _http.post(
    //_uri(path),
    //headers: await _headers(),
    //7body: jsonEncode(body),
    //);
  }

  Future<http.Response> patch(String path, Object body) async {
    return _http.patch(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, Object body) async {
    return _http.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) async {
    return _http.delete(_uri(path), headers: await _headers());
  }

  Future<http.Response> getRaw(String path) async {
    final uri = Uri.parse('$Env.baseUrl$path');
    // No forzamos content-type aquí
    final access = await tokens.readAccess();
    final h = <String, String>{};
    if (access != null && access.isNotEmpty) {
      h['Authorization'] = 'Bearer $access';
    }
    return _http.get(uri, headers: h);
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
