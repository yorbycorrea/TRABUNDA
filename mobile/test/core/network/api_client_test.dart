import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/token_storage.dart';

// 1) Mock de TokenStorage
class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('ApiClient GET agrega Authorization cuando hay token', () async {
    // Mock de TokenStorage
    final tokens = MockTokenStorage();

    // Stub: readAccess devuelve token
    when(() => tokens.readAccess()).thenAnswer((_) async => 'ABC123');

    // Mock HTTP para capturar request
    late http.Request captured;
    final mockHttp = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens,
      httpClient: mockHttp,
    );

    final resp = await api.get('/ping');

    expect(resp.statusCode, 200);
    expect(captured.url.toString(), 'http://example.com/ping');
    expect(captured.headers['Content-Type'], 'application/json');
    expect(captured.headers['Authorization'], 'Bearer ABC123');
  });

  test('ApiClient GET NO agrega Authorization si token es null', () async {
    final tokens = MockTokenStorage();
    when(() => tokens.readAccess()).thenAnswer((_) async => null);

    late http.Request captured;
    final mockHttp = MockClient((req) async {
      captured = req;
      return http.Response('OK', 200);
    });

    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens,
      httpClient: mockHttp,
    );

    await api.get('/ping');

    expect(captured.headers.containsKey('Authorization'), false);
    expect(captured.headers['Content-Type'], 'application/json');
  });

  test('ApiClient POST manda body en JSON', () async {
    final tokens = MockTokenStorage();
    when(() => tokens.readAccess()).thenAnswer((_) async => 'XYZ');

    late http.Request captured;
    final mockHttp = MockClient((req) async {
      captured = req;
      return http.Response('OK', 200);
    });

    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens,
      httpClient: mockHttp,
    );

    await api.post('/login', {'user': 'a', 'pass': 'b'});

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://example.com/login');
    expect(captured.headers['Authorization'], 'Bearer XYZ');

    final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(decoded['user'], 'a');
    expect(decoded['pass'], 'b');
  });
}
