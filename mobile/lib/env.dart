import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  static const String _devFallbackApiUrl =
      'http://vserver.trabunda.com:3000'; // despues cambiar esto
  static const String _prodFallbackApiUrl = 'http://vserver.trabunda.com:3000';

  static Uri get resolvedBaseUri {
    final fallbackApiUrl = kReleaseMode
        ? _prodFallbackApiUrl
        : _devFallbackApiUrl;
    final rawApiUrl = dotenv.env['API_URL'] ?? fallbackApiUrl;
    final parsed = Uri.parse(rawApiUrl);

    final scheme = parsed.scheme.toLowerCase();

    if (scheme != 'http' && scheme != 'https') {
      throw StateError(
        'API_URL debe usar esquema http o https. Valor recibido: "$rawApiUrl".',
      );
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path.replaceFirst(RegExp(r'/+$'), '')
        : parsed.path;

    return parsed.replace(path: normalizedPath);
  }

  static String get apiBaseUrl => resolvedBaseUri.toString();
}
