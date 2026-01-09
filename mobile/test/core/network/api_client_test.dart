import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Importa tu ApiClient real
import 'package:mobile/core/network/api_client.dart';

// Importa el fake
import '../../fakes/fake_token_storage.dart';

void main() {
  test('ApiClient GET agrega Authorization cuando hay token', () async {
    // 1) Creamos un MockClient para interceptar el request
    late http.Request captured;

    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    // 2) Tokens fake con un access token
    final tokens = FakeTokenStorage(access: 'ABC123');

    // 3) ApiClient usando el mock http client
    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens as dynamic, // <- explico abajo
      httpClient: mock,
    );

    // 4) Ejecutamos GET
    final resp = await api.get('/ping');

    // 5) Verificaciones
    expect(resp.statusCode, 200);
    expect(captured.url.toString(), 'http://example.com/ping');

    // Headers: Content-Type y Authorization
    expect(captured.headers['Content-Type'], 'application/json');
    expect(captured.headers['Authorization'], 'Bearer ABC123');
  });

  test('ApiClient GET NO agrega Authorization si token es null', () async {
    late http.Request captured;

    final mock = MockClient((req) async {
      captured = req;
      return http.Response('OK', 200);
    });

    final tokens = FakeTokenStorage(access: null);

    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens as dynamic,
      httpClient: mock,
    );

    await api.get('/ping');

    expect(captured.headers.containsKey('Authorization'), false);
    expect(captured.headers['Content-Type'], 'application/json');
  });

  test('ApiClient POST manda body en JSON', () async {
    late http.Request captured;

    final mock = MockClient((req) async {
      captured = req;
      return http.Response('OK', 200);
    });

    final tokens = FakeTokenStorage(access: 'XYZ');

    final api = ApiClient(
      baseUrl: 'http://example.com',
      tokens: tokens as dynamic,
      httpClient: mock,
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
