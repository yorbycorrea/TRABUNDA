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
    required this.codigo,
    required this.inicio,
  });

  final int? trabajadorId;
  final String codigo;
  final TimeOfDay? inicio;
}

class ValidateSaneamientoLineas {
  const ValidateSaneamientoLineas();

  String? validarMinimo(List<SaneamientoLineaValidation> items) {
    for (final item in items) {
      if (item.trabajadorId == null || item.inicio == null) {
        return 'Escanea trabajador y selecciona Hora inicio';
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

      if (trabajadorId == null && cod.isNotEmpty && it.codigo == cod) {
        return true;
      }
    }
    return false;
  }
}
