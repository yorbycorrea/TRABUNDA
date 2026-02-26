import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static const String _baseUrlFromDefine = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  static Uri get resolvedBaseUri {
    final fromDefine = _baseUrlFromDefine.trim();
    final fromDotenvBase = (dotenv.env['BASE_URL'] ?? '').trim();
    final fromDotenvApi = (dotenv.env['API_URL'] ?? '').trim();

    final value = fromDefine.isNotEmpty
        ? fromDefine
        : (fromDotenvBase.isNotEmpty ? fromDotenvBase : fromDotenvApi);

    if (value.isEmpty) {
      throw StateError(
        'Falta BASE_URL (dart-define o .env). También se acepta API_URL como fallback.',
      );
    }
    final parsed = Uri.parse(value);
    final scheme = parsed.scheme.toLowerCase();

    if (scheme != 'http' && scheme != 'https') {
      throw StateError(
        'BASE_URL debe usar esquema http o https. Valor recibido: "$value".',
      );
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path.replaceFirst(RegExp(r'/+$'), '')
        : parsed.path;

    return parsed.replace(path: normalizedPath);
  }
}
