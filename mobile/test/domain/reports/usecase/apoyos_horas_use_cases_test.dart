import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/reports/usecase/apoyos_horas_use_cases.dart';

void main() {
  group('ValidateApoyoHorasLineas.existsDuplicate', () {
    final validator = ValidateApoyoHorasLineas();

    test('ignora trabajadorId contaminado y no marca duplicado si codigo/dni no coinciden', () {
      final lineas = [
        ApoyoHorasLineaInput(
          lineaId: 9,
          trabajadorId: 34514,
          codigo: '26755',
          documento: '75121306',
          inicio: null,
          areaId: null,
        ),
      ];

      final duplicated = validator.existsDuplicate(
        lineas: lineas,
        trabajadorId: 34514,
        codigo: '34514',
        documento: '61041586',
      );

      expect(duplicated, false);
    });

    test('marca duplicado cuando se escanea nuevamente el mismo codigo', () {
      final lineas = [
        ApoyoHorasLineaInput(
          lineaId: 1,
          trabajadorId: 34514,
          codigo: '34514',
          documento: '61041586',
          inicio: null,
          areaId: null,
        ),
      ];

      final duplicated = validator.existsDuplicate(
        lineas: lineas,
        trabajadorId: 99999,
        codigo: '34514',
        documento: '00000000',
      );

      expect(duplicated, true);
    });

    test('marca duplicado por dni cuando codigo no coincide', () {
      final lineas = [
        ApoyoHorasLineaInput(
          lineaId: 2,
          trabajadorId: 11111,
          codigo: '26755',
          documento: '61041586',
          inicio: null,
          areaId: null,
        ),
      ];

      final duplicated = validator.existsDuplicate(
        lineas: lineas,
        trabajadorId: 22222,
        codigo: '34514',
        documento: '61041586',
      );

      expect(duplicated, true);
    });
  });

  group('MapQrToApoyoHorasModel', () {
    final mapper = MapQrToApoyoHorasModel();

    test('mantiene ceros a la izquierda en codigo', () {
      final mapped = mapper.call({
        'codigo': '03098',
        'dni': '12345678',
        'nombre_completo': 'Trabajador Test',
      });

      expect(mapped.codigo, '03098');
    });
  });
}
