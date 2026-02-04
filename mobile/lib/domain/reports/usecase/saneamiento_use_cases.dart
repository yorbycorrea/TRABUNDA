import 'package:flutter/material.dart';

class CalculateHoras {
  double call(TimeOfDay inicio, TimeOfDay fin) {
    final start = Duration(hours: inicio.hour, minutes: inicio.minute);
    final end = Duration(hours: fin.hour, minutes: fin.minute);
    final diff = end - start;
    return diff.inMinutes / 60.0;
  }
}

class SaneamientoLineaValidation {
  const SaneamientoLineaValidation({
    required this.trabajadorId,
    required this.trabajadorCodigo,
    required this.inicio,
    required this.labores,
    required this.activo,
  });

  final int? trabajadorId;
  final String trabajadorCodigo;
  final TimeOfDay? inicio;
  final String labores;
  final bool activo;
}

class ValidateSaneamientoLineas {
  const ValidateSaneamientoLineas();

  String? validarMinimo(List<SaneamientoLineaValidation> items) {
    for (final item in items) {
      if (!item.activo) {
        continue;
      }

      final codigoVacio = item.trabajadorCodigo.trim().isEmpty;
      if (item.trabajadorId == null && codigoVacio) {
        return 'Escanea trabajador o ingresa código';
      }
      if (item.inicio == null) {
        return 'Selecciona Hora inicio';
      }
      if (item.labores.trim().isEmpty) {
        return 'Describe las labores';
      }
    }
    return null;
  }

  bool yaExisteTrabajador({
    required List<SaneamientoLineaValidation> items,
    int? trabajadorId,
    String? codigo,
    int? exceptIndex,
  }) {
    final cod = (codigo ?? '').trim();
    for (var i = 0; i < items.length; i++) {
      if (exceptIndex != null && i == exceptIndex) continue;
      final it = items[i];

      if (trabajadorId != null && it.trabajadorId == trabajadorId) return true;

      if (trabajadorId == null &&
          cod.isNotEmpty &&
          it.trabajadorCodigo == cod) {
        return true;
      }
    }
    return false;
  }
}
