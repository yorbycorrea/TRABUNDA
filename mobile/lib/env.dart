class Config {
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static Uri get resolvedBaseUri {
    final value = _rawApiBaseUrl.trim();

    if (value.isEmpty) {
      throw StateError(
        'Falta API_BASE_URL. Debes pasar --dart-define=API_BASE_URL=http://host:puerto.',
      );
    }
    final parsed = Uri.parse(value);
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw StateError(
        'API_BASE_URL debe usar esquema http o https. Valor recibido: "$value".',
      );
    }

    final normalizedPath = parsed.path.endsWith('/') && parsed.path.length > 1
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;

    return parsed.replace(path: normalizedPath);
  }

  static String get apiBaseUrl => resolvedBaseUri.toString();
  // Esto lee la variable API_URL del archivo .env
  //static String get baseUrl =>
  //dotenv.env['API_URL'] ?? 'http://172.16.1.207:3000';
}
