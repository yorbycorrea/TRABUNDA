import 'package:flutter/material.dart';

class ApoyoHorasLineaInput {
  ApoyoHorasLineaInput({
    required this.lineaId,
    required this.trabajadorId,
    required this.codigo,
    required this.inicio,
    required this.areaId,
  });
  final int? lineaId;
  final int? trabajadorId;
  final String codigo;
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
    final start = Duration(hours: inicio.hour, minutes: inicio.minute);
    final end = Duration(hours: fin.hour, minutes: fin.minute);
    final diff = end - start;
    return diff.inMinutes / 60.0;
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
    int? exceptIndex,
  }) {
    final cod = (codigo ?? '').trim();

    for (var i = 0; i < lineas.length; i++) {
      if (exceptIndex != null && i == exceptIndex) continue;

      final linea = lineas[i];

      if (trabajadorId != null && linea.trabajadorId == trabajadorId) {
        return true;
      }

      final lineaCodigo = linea.codigo.trim();
      if (trabajadorId == null && cod.isNotEmpty && lineaCodigo == cod) {
        return true;
      }
    }

    return false;
  }
}
