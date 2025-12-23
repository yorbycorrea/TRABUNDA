import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Esto lee la variable API_URL de tu archivo .env
  static String baseUrl = dotenv.get(
    'API_URL',
    fallback: 'http://10.0.2.2:3000',
  );
}
