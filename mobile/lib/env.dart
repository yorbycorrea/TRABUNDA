import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  static const String _devFallbackApiUrl = 'http://172.16.1.207:3000';
  static const String _prodFallbackApiUrl = 'https://vserver.trabunda.com';

  static Uri get resolvedBaseUri {
    final fallbackApiUrl = kReleaseMode
        ? _prodFallbackApiUrl
        : _devFallbackApiUrl;
    final rawApiUrl = dotenv.env['API_URL'] ?? fallbackApiUrl;
    final parsed = Uri.parse(rawApiUrl);

    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw StateError(
        'API_URL debe usar esquema http o https. Valor recibido: "$rawApiUrl".',
      );
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;

    return parsed.replace(path: normalizedPath);
  }

  static String get baseUrl => resolvedBaseUri.toString();
  // Esto lee la variable API_URL de tu archivo .env
  //static String get baseUrl =>
  //dotenv.env['API_URL'] ?? 'http://172.16.1.207:3000';
}
