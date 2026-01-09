import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

// IMPORTA TU LOGIN REAL
import 'package:mobile/features/auth/presentation/login_page.dart';

// IMPORTA TU AUTH CONTROLLER REAL (scope + tipos)
import 'package:mobile/features/auth/controller/auth_controller.dart';

// ----------------------------
// 1) Mock del controlador
// ----------------------------
class MockAuthController extends Mock implements AuthController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ByteData para AssetManifest.bin válido (StandardMessageCodec con un Map vacío)
  final ByteData emptyManifestBin = () {
    final data = const StandardMessageCodec().encodeMessage(
      <String, dynamic>{},
    );
    return data!; // YA es ByteData correcto
  }();

  // AssetManifest.json vacío válido
  final ByteData emptyManifestJson = () {
    final bytes = utf8.encode('{}');
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }();

  // PNG 1x1 transparente válido (para que Image.asset no falle)
  final ByteData onePxTransparentPng = () {
    const b64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+lmfkAAAAASUVORK5CYII=';
    final bytes = base64Decode(b64);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }();

  setUpAll(() async {
    // Mock del PackageInfo para que _loadVersion() no falle
    PackageInfo.setMockInitialValues(
      appName: 'TRABUNDA',
      packageName: 'com.trabunda.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Mock del canal de assets (rootBundle usa esto)
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());

        // Flutter puede pedir cualquiera de estos dos manifests
        if (key.endsWith('AssetManifest.bin')) return emptyManifestBin;
        if (key.endsWith('AssetManifest.json')) return emptyManifestJson;

        // Tu logo del LoginPage
        if (key.endsWith('assets/icon/logo.png')) return onePxTransparentPng;

        // Para cualquier otro asset: devolvemos null
        return null;
      },
    );

    // (Opcional) canal de package_info_plus para evitar warnings
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/package_info_plus',
      (message) async => null,
    );
  });

  // Helper: construye el widget bajo prueba con Scope + MaterialApp
  Widget buildTestApp(AuthController auth) {
    return MaterialApp(
      home: AuthControllerScope(controller: auth, child: const LoginPage()),
    );
  }

  testWidgets('1) Muestra error si Usuario está vacío', (tester) async {
    // Arrange
    final auth = MockAuthController();

    when(() => auth.status).thenReturn(AuthStatus.unauthenticated);
    when(() => auth.errorMessage).thenReturn(null);

    await tester.pumpWidget(buildTestApp(auth));

    // Act: presionar "Entrar" sin llenar nada
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    // Assert
    expect(find.text('Ingresa tu usuario'), findsOneWidget);

    verifyNever(
      () => auth.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('2) Muestra error si contraseña tiene menos de 8 caracteres', (
    tester,
  ) async {
    final auth = MockAuthController();
    when(() => auth.status).thenReturn(AuthStatus.unauthenticated);
    when(() => auth.errorMessage).thenReturn(null);

    await tester.pumpWidget(buildTestApp(auth));

    // Llenar usuario válido
    await tester.enterText(find.byType(TextFormField).at(0), '42093186');

    // Llenar pass corta
    await tester.enterText(find.byType(TextFormField).at(1), '1234');

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Minimo 8 caracteres'), findsOneWidget);

    verifyNever(
      () => auth.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('3) Si login falla, muestra banner con errorMessage', (
    tester,
  ) async {
    final auth = MockAuthController();

    when(() => auth.status).thenReturn(AuthStatus.unauthenticated);
    when(() => auth.errorMessage).thenReturn('Credenciales inválidas');

    when(
      () => auth.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(buildTestApp(auth));

    await tester.enterText(find.byType(TextFormField).at(0), '42093186');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);

    verify(
      () => auth.login(username: '42093186', password: '12345678'),
    ).called(1);
  });
}
