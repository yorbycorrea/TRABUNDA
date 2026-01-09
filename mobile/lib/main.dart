// 1. Imports de Flutter/Dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:mobile/core/network/token_storage.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_api_service.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/env.dart';

import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/menu/presentation/pages/menu_page.dart';
import 'package:mobile/menu/presentation/pages/report_create_planillero_page.dart';
import 'package:mobile/features/state_apoyo_horas.dart';
import 'package:mobile/menu/presentation/pages/report_view_page.dart';
import 'package:mobile/menu/presentation/pages/report_create_saneamiento_page.dart';

import 'package:mobile/core/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final theme = ThemeData(
    scaffoldBackgroundColor: AppColors.lightCyan,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.frenchBlue,
      primary: AppColors.frenchBlue,
      secondary: AppColors.turquoise,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.frenchBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.frenchBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  // Inyección de dependencias
  final tokenStorage = TokenStorage(const FlutterSecureStorage());
  final apiClient = ApiClient(baseUrl: Env.baseUrl, tokens: tokenStorage);
  final authController = AuthController(
    authApi: AuthApiService(apiClient),
    api: apiClient,
  );

  runApp(
    AuthControllerScope(
      controller: authController,
      child: TrabundaApp(api: apiClient, theme: theme),
    ),
  );
}

class TrabundaApp extends StatelessWidget {
  const TrabundaApp({super.key, required this.api, required this.theme});

  final ApiClient api;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trabunda App',
      debugShowCheckedModeBanner: false,
      theme: theme, // ✅ AQUÍ se aplica la paleta

      onGenerateRoute: (settings) {
        debugPrint('Navegando a ruta: ${settings.name}');
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeMenuPage());

          case '/reports/create':
            return MaterialPageRoute(
              builder: (_) => ReportCreatePlanilleroPage(api: api),
            );

          case '/apoyos_horas':
            return MaterialPageRoute(
              builder: (_) => ApoyosHorasHomePage(api: api, turno: 'Dia'),
            );

          case '/reports/list':
            return MaterialPageRoute(builder: (_) => ReportViewPage(api: api));

          case '/reports/create_saneamiento': // ✅ le faltaba el slash al inicio
            return MaterialPageRoute(
              builder: (_) => ReportCreateSaneamientoPage(api: api),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Ruta no encontrada')),
              ),
            );
        }
      },

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

    switch (auth.status) {
      case AuthStatus.loading:
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case AuthStatus.authenticated:
        return const HomeMenuPage();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginPage();
    }
  }
}
