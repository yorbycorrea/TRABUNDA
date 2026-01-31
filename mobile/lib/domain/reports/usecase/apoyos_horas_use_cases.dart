import 'package:flutter/material.dart';

class ApoyoHorasLineaInput {
  ApoyoHorasLineaInput({
    required this.trabajadorId,
    required this.codigo,
    required this.inicio,
    required this.areaId,
  });

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
  });

  final int? trabajadorId;
  final String codigo;
  final String nombre;
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
    final trabajadorId = idNum?.toInt();

    var codigo = (result['codigo'] ?? '').toString().trim();
    if (codigo.isEmpty && worker is Map) {
      codigo = (worker['codigo'] ?? '').toString().trim();
    }
    final dni = (result['dni'] ?? '').toString().trim();
    final codigoFinal = codigo.isNotEmpty ? codigo : dni;

    final nombre = (result['nombre_completo'] ?? result['nombre'] ?? '')
        .toString()
        .trim();

    debugPrint(
      'MapQrToApoyoHorasModel -> codigo=$codigoFinal nombre=$nombre trabajadorId=$trabajadorId',
    );

    return ApoyoHorasScanResult(
      trabajadorId: trabajadorId,
      codigo: codigoFinal,
      nombre: nombre,
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
      if (linea.trabajadorId == null ||
          linea.inicio == null ||
          linea.areaId == null) {
        return 'Escanea trabajador, selecciona hora inicio y área';
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
