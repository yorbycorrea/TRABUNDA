import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  static const String _fallbackApiUrl = 'http://172.16.1.207:3000';

  static Uri get resolvedBaseUri {
    final rawApiUrl = dotenv.env['API_URL'] ?? _fallbackApiUrl;
    final parsed = Uri.parse(rawApiUrl);

    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw StateError(
        'API_URL debe usar esquema http o https. Valor recibido: "$rawApiUrl".',
      );
    }

    final nonProdVserver =
        !kReleaseMode &&
        parsed.host == 'vserver.trabunda.com' &&
        parsed.port == 3000;

    final adjusted = nonProdVserver ? parsed.replace(scheme: 'http') : parsed;

    final normalizedPath = adjusted.path.endsWith('/')
        ? adjusted.path.substring(0, adjusted.path.length - 1)
        : adjusted.path;

    return adjusted.replace(path: normalizedPath);
  }

  static String get baseUrl => resolvedBaseUri.toString();
  // Esto lee la variable API_URL de tu archivo .env
  //static String get baseUrl =>
  //dotenv.env['API_URL'] ?? 'http://172.16.1.207:3000';
}
