import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiClient {
  final String baseUrl;
  final TokenStorage tokens;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final access = await tokens.readAccess();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (access != null && access.isNotEmpty) {
      h['Autorization'] = 'Bearer $access';
    }
    return h;
  }

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _http.get(uri, headers: await _headers());
  }

  Future<http.Response> post(String path, Object body) async {
    final uri = Uri.parse('$baseUrl$path');
    return _http.post(uri, headers: await _headers(), body: jsonEncode(body));
  }
}
