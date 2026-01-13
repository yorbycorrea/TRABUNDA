import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Esto lee la variable API_URL de tu archivo .env
  static String baseUrl = dotenv.get(
    'API_URL',
    //fallback: 'http://172.16.1.207:3000',
    fallback: 'http://192.168.60.102:3000',
  );
}
