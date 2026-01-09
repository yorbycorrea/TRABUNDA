// lib/core/utils/validators.dart

/// Normaliza variantes comunes del turno a un valor estándar.
/// Devuelve 'Dia' o 'Noche'. Si no reconoce, devuelve null.
String? normalizarTurno(String? input) {
  if (input == null) return null;

  final raw = input.trim().toLowerCase();
  if (raw.isEmpty) return null;

  // Opcionales: soporta tildes y variantes
  final cleaned = raw
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  if (cleaned == 'dia' || cleaned == 'd' || cleaned == 'day') return 'Dia';
  if (cleaned == 'noche' || cleaned == 'n' || cleaned == 'night')
    return 'Noche';

  return null;
}

bool esTurnoValido(String? turno) => turno == 'Dia' || turno == 'Noche';
