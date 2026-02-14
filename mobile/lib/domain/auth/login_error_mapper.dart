class LoginErrorMapper {
  const LoginErrorMapper();

  String friendlyMessage(String raw) {
    final code = _normalizeCode(raw);

    switch (code) {
      case 'network_timeout':
        return 'La conexión está tardando. Intenta nuevamente.';
      case 'network_unreachable':
        return 'No hay conexión. Revisa tu Wifi o datos móviles.';
      case 'ssl_error':
        return 'No se pudo establecer una conexión segura.';
      case 'bad_response':
        return 'El servidor respondió de forma inesperada. Intenta nuevamente.';
      default:
        if (raw.contains('401') || raw.contains('403')) {
          return 'Usuario o contraseña incorrectos.';
        }
        return 'No se pudo iniciar sesión. Intenta nuevamente.';
    }
  }

  String _normalizeCode(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.startsWith('exception:')) {
      return trimmed.replaceFirst('exception:', '').trim();
    }

    return trimmed;
  }
}
