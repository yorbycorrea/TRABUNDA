import 'package:flutter/material.dart';

class ApoyoHorasLineaInput {
  ApoyoHorasLineaInput({
    required this.lineaId,
    required this.trabajadorId,
    required this.codigo,
    required this.documento,
    required this.inicio,
    required this.areaId,
  });
  final int? lineaId;
  final int? trabajadorId;
  final String codigo;
  final String? documento;
  final TimeOfDay? inicio;
  final int? areaId;
}

class ApoyoHorasScanResult {
  ApoyoHorasScanResult({
    required this.trabajadorId,
    required this.codigo,
    required this.nombre,
    required this.documento,
  });

  final int? trabajadorId;
  final String codigo;
  final String nombre;
  final String documento;
}

class CalculateHoras {
  double call(TimeOfDay inicio, TimeOfDay fin) {
    final inicioMin = (inicio.hour * 60) + inicio.minute;
    final finOriginalMin = (fin.hour * 60) + fin.minute;

    var finMin = finOriginalMin;
    if (finMin < inicioMin) {
      finMin += 24 * 60;
    }

    var duracionMin = finMin - inicioMin;
    duracionMin -= 30;

    if (duracionMin < 0) {
      return 0;
    }

    final duracionHoras = duracionMin / 60.0;
    final redondeadoMediaHora = (duracionHoras * 2).round() / 2;
    return double.parse(redondeadoMediaHora.toStringAsFixed(1));
  }
}

class MapQrToApoyoHorasModel {
  ApoyoHorasScanResult call(Map<String, dynamic> result) {
    final worker = result['worker'];
    final idAny = result['id'] ?? (worker is Map ? worker['id'] : null);
    final idNum = (idAny is num)
        ? idAny
        : num.tryParse(idAny?.toString() ?? '');
    var trabajadorId = idNum?.toInt();

    var codigo = (result['codigo'] ?? '').toString().trim();
    if (codigo.isEmpty && worker is Map) {
      codigo = (worker['codigo'] ?? '').toString().trim();
    }
    final dni = (result['dni'] ?? (worker is Map ? worker['dni'] : null) ?? '')
        .toString()
        .trim();
    final codigoFinalRaw = codigo.isNotEmpty ? codigo : dni;
    final codigoFinal = RegExp(r'^\d+$').hasMatch(codigoFinalRaw)
        ? codigoFinalRaw.padLeft(5, '0')
        : codigoFinalRaw;

    if (trabajadorId == null) {
      final codigoWorker = worker is Map ? worker['codigo'] : null;
      final codigoResult = result['codigo'];
      final codigoFallback = codigoWorker ?? codigoResult;
      trabajadorId = int.tryParse(codigoFallback?.toString() ?? '');
    }

    final nombre =
        (result['nombre_completo'] ??
                (worker is Map ? worker['nombre'] : null) ??
                result['nombre'] ??
                '')
            .toString()
            .trim();

    debugPrint(
      'MapQrToApoyoHorasModel -> codigo=$codigoFinal nombre=$nombre trabajadorId=$trabajadorId',
    );

    return ApoyoHorasScanResult(
      trabajadorId: trabajadorId,
      codigo: codigoFinal,
      nombre: nombre,
      documento: dni,
    );
  }
}

class ValidateApoyoHorasLineas {
  String? call(List<ApoyoHorasLineaInput> lineas) {
    final seenIds = <int>{};
    final seenCods = <String>{};

    for (final linea in lineas) {
      final id = linea.trabajadorId;
      final codigo = linea.codigo.trim();

      if (id != null) {
        if (!seenIds.add(id)) {
          return 'Hay trabajadores repetidos. Elimina el duplicado.';
        }
      } else if (codigo.isNotEmpty) {
        if (!seenCods.add(codigo)) {
          return 'Hay códigos repetidos. Elimina el duplicado.';
        }
      }
    }

    for (final linea in lineas) {
      final codigo = linea.codigo.trim();
      final hasTrabajador =
          linea.lineaId != null ||
          linea.trabajadorId != null ||
          codigo.isNotEmpty;
      if (!hasTrabajador) {
        return 'Escanea trabajador';
      }
      if (linea.inicio == null || linea.areaId == null) {
        return 'Selecciona hora inicio y área';
      }
    }

    return null;
  }

  bool existsDuplicate({
    required List<ApoyoHorasLineaInput> lineas,
    required int? trabajadorId,
    required String? codigo,
    String? documento,
    int? exceptIndex,
  }) {
    final codRaw = codigo;
    final cod = (codigo ?? '').trim();
    final dniRaw = documento;
    final dni = (documento ?? '').trim();

    debugPrint(
      '[existsDuplicate] NEW codigo=$codRaw(${codRaw.runtimeType}) -> trim="$cod" '
      'dni=$dniRaw(${dniRaw.runtimeType}) -> trim="$dni" '
      'trabajadorId=$trabajadorId(${trabajadorId.runtimeType}) '
      'exceptIndex=$exceptIndex(${exceptIndex.runtimeType})',
    );
    // APOYO_HORAS: no usar trabajadorId para duplicados porque ese campo
    // puede venir contaminado y no representa el PK real en este flujo.
    // La unicidad se decide por codigo (String) y opcionalmente por DNI.
    debugPrint('[existsDuplicate] strategy: matchCodigo || matchDni');

    for (var i = 0; i < lineas.length; i++) {
      if (exceptIndex != null && i == exceptIndex) {
        debugPrint(
          '[existsDuplicate] ITEM[$i] skipped by exceptIndex. i=$i exceptIndex=$exceptIndex',
        );
        continue;
      }

      final linea = lineas[i];
      final itemCodigoRaw = linea.codigo;
      final itemCodigo = linea.codigo.trim();
      final itemDniRaw = linea.documento;
      final itemDni = (linea.documento ?? '').trim();
      final matchCodigo = cod.isNotEmpty && itemCodigo == cod;
      final matchDni = dni.isNotEmpty && itemDni.isNotEmpty && itemDni == dni;

      debugPrint(
        '[existsDuplicate] ITEM[$i] '
        'codigo=$itemCodigoRaw(${itemCodigoRaw.runtimeType}) -> trim="$itemCodigo" '
        'dni=$itemDniRaw(${itemDniRaw.runtimeType}) -> trim="$itemDni" '
        'trabajadorId=${linea.trabajadorId}(${linea.trabajadorId.runtimeType})',
      );
      debugPrint(
        '[existsDuplicate] ITEM[$i] compare: '
        'matchCodigo=$matchCodigo '
        'matchDni=$matchDni '
        '| newCodigoEmpty=${cod.isEmpty} newDniEmpty=${dni.isEmpty} itemDniEmpty=${itemDni.isEmpty}',
      );

      if (matchCodigo || matchDni) {
        debugPrint(
          '[existsDuplicate] RETURN true by ${matchCodigo ? 'matchCodigo' : 'matchDni'}',
        );
        return true;
      }
    }

    debugPrint('[existsDuplicate] RETURN false (no matches found)');

    return false;
  }
}
