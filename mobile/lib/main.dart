// 1. Imports de Flutter/Dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/network/token_storage.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_api_service.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/env.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Inyección de dependencias
  final tokenStorage = TokenStorage(const FlutterSecureStorage());
  final apiClient = ApiClient(baseUrl: Env.baseUrl, tokens: tokenStorage);
  final authController = AuthController(
    authApi: AuthApiService(apiClient),
    api: apiClient,
  );

  runApp(
    AuthControllerScope(controller: authController, child: const TrabundaApp()),
  );
}

class TrabundaApp extends StatelessWidget {
  const TrabundaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trabunda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      // El MaterialApp envuelve a toda la app una sola vez
      home: const AuthRouter(),
    );
  }
}

class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  @override
  void initState() {
    super.initState();
    // Disparamos la validación del token al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthControllerScope.read(context).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios de estado
    final auth = AuthControllerScope.of(context);

    //
    switch (auth.status) {
      case AuthStatus.loading:
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case AuthStatus.authenticated:
        // Placeholder mientras creas MenuPage
        return const Scaffold(
          body: Center(child: Text('Sesión Iniciada - Aquí irá MenuPage')),
        );

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        // Placeholder mientras creas LoginPage
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No autenticado - Aquí irá LoginPage'),
                if (auth.errorMessage != null)
                  Text(
                    auth.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        );
    }
  }
}
