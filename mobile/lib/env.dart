import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Esto lee la variable API_URL de tu archivo .env
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? 'http://172.16.1.207:3000';
}
