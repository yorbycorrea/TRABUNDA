// 1. Imports de Flutter/Dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:mobile/core/network/token_storage.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/data/auth/auth_repository_impl.dart';
import 'package:mobile/data/auth/remote/auth_remote_data_source.dart';
import 'package:mobile/domain/auth/usecases/get_current_user.dart';
import 'package:mobile/domain/auth/usecases/login.dart';
import 'package:mobile/domain/auth/usecases/logout.dart';
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

Future<void> bootstrapApp({required String envFile}) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Esto carga el archivo físico .env en la memoria de la app
    await dotenv.load(fileName: envFile);
    print(" Variables de entorno cargadas: ${dotenv.env['API_URL']}");
  } catch (e) {
    print(" Error cargando $envFile: $e");
  }

  final envFileName = kReleaseMode ? '.env.prod' : '.env.dev';
  try {
    await dotenv.load(fileName: envFileName);
    debugPrint('dotenv cargado desde: $envFileName');
  } catch (e) {
    debugPrint('No se pudo cargar $envFileName: $e');
  }

  // Valida configuración obligatoria al iniciar la app.

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
  final apiClient = ApiClient(tokens: tokenStorage);
  final authRepository = AuthRepositoryImpl(
    remote: AuthRemoteDataSource(apiClient),
  );

  final authController = AuthController(
    getCurrentUser: GetCurrentUser(authRepository),
    login: Login(authRepository),
    logout: Logout(authRepository),
  );

  runApp(
    AuthControllerScope(
      controller: authController,
      child: TrabundaApp(api: apiClient, theme: theme),
    ),
  );
}

Future<void> main() async {
  await bootstrapApp(envFile: ".env");
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
      theme: theme,

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

          case '/reports/create_saneamiento':
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

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.technicalDetail});

  final String technicalDetail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConfigErrorPage(technicalDetail: technicalDetail),
    );
  }
}

class ConfigErrorPage extends StatelessWidget {
  const ConfigErrorPage({super.key, required this.technicalDetail});

  final String technicalDetail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BASE_URL no configurado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                technicalDetail,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => bootstrapApp(envFile: ".env"),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_ConfigCandidate _detectBaseUrlCandidate() {
  const fromDefine = String.fromEnvironment('BASE_URL', defaultValue: '');
  final fromDotenvBase = (dotenv.env['BASE_URL'] ?? '').trim();
  final fromDotenvApi = (dotenv.env['API_URL'] ?? '').trim();

  if (fromDefine.trim().isNotEmpty) {
    return _ConfigCandidate(
      source: 'dart-define BASE_URL',
      value: fromDefine.trim(),
    );
  }
  if (fromDotenvBase.isNotEmpty) {
    return _ConfigCandidate(source: '.env BASE_URL', value: fromDotenvBase);
  }
  if (fromDotenvApi.isNotEmpty) {
    return _ConfigCandidate(source: '.env API_URL', value: fromDotenvApi);
  }

  return const _ConfigCandidate(source: 'sin origen detectado', value: null);
}

class _ConfigCandidate {
  const _ConfigCandidate({required this.source, required this.value});

  final String source;
  final String? value;
}

class _AuthRouterState extends State<AuthRouter> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthControllerScope.read(context).init();
    });
  }

  @override
  Widget build(BuildContext context) {
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
