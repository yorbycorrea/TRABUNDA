class LoginErrorMapper {
  const LoginErrorMapper();

  String friendlyMessage(String raw) {
    final s = raw.toLowerCase();

    // Credenciales
    if (s.contains('401') ||
        s.contains('403') ||
        s.contains('credenciales') ||
        s.contains('invalid') ||
        s.contains('unauthorized')) {
      return 'Usuario o contraseña incorrectos.';
    }

    // Conexion / red
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'La conexión esta tardando. Intenta nuevamente.';
    }
    if (s.contains('socket') ||
        s.contains('failed host') ||
        s.contains('network') ||
        s.contains('connection')) {
      return 'No hay conexion. Revisa tu Wifi o datos moviles.';
    }

    return 'No se pudo iniciar sesión. Intenta Nuevamente.';
  }
}
