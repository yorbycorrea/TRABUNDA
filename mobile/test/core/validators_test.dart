// test/core/utils/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/validators.dart';

void main() {
  group('normalizarTurno', () {
    test('convierte variantes de Dia a "Dia"', () {
      expect(normalizarTurno('Dia'), 'Dia');
      expect(normalizarTurno('día'), 'Dia');
      expect(normalizarTurno('  DIA  '), 'Dia');
      expect(normalizarTurno('d'), 'Dia');
    });

    test('convierte variantes de Noche a "Noche"', () {
      expect(normalizarTurno('Noche'), 'Noche');
      expect(normalizarTurno('  noche '), 'Noche');
      expect(normalizarTurno('n'), 'Noche');
    });

    test('devuelve null si es inválido', () {
      expect(normalizarTurno(null), null);
      expect(normalizarTurno(''), null);
      expect(normalizarTurno('tarde'), null);
      expect(normalizarTurno('mañana'), null);
    });
  });

  group('esTurnoValido', () {
    test('solo acepta "Dia" o "Noche"', () {
      expect(esTurnoValido('Dia'), true);
      expect(esTurnoValido('Noche'), true);
      expect(
        esTurnoValido('día'),
        false,
      ); // ojo: aquí debe venir ya normalizado
      expect(esTurnoValido('tarde'), false);
      expect(esTurnoValido(null), false);
    });
  });
}
