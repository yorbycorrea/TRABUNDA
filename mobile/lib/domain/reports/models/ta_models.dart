double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class TaCuadrilla {
  final int id;
  final String tipo; // RECEPCION | FILETEADO | APOYO_RECEPCION
  final String nombre;
  final String? horaInicio;
  final String? horaFin;
  final double produccionKg;
  final int? apoyoDeCuadrillaId;

  TaCuadrilla({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.horaInicio,
    required this.horaFin,
    required this.produccionKg,
    required this.apoyoDeCuadrillaId,
  });

  factory TaCuadrilla.fromJson(Map<String, dynamic> j) => TaCuadrilla(
    id: (j['id'] as num).toInt(),
    tipo: (j['tipo'] ?? '').toString(),
    nombre: (j['nombre'] ?? '').toString(),
    horaInicio: j['hora_inicio']?.toString(),
    horaFin: j['hora_fin']?.toString(),
    produccionKg: toDouble(j['produccion_kg']), // ✅ aquí está el fix real
    apoyoDeCuadrillaId: toIntOrNull(j['apoyo_de_cuadrilla_id']),
  );
}

class TaTrabajador {
  final int id;
  final String codigo;
  final String nombreCompleto;
  final double kg;

  TaTrabajador({
    required this.id,
    required this.codigo,
    required this.nombreCompleto,
    required this.kg,
  });

  factory TaTrabajador.fromJson(Map<String, dynamic> j) {
    // Soporta distintas claves según el endpoint
    final codigo = (j['codigo'] ?? j['trabajador_codigo'] ?? '')
        .toString()
        .trim();

    final nombre =
        (j['nombre_completo'] ?? j['trabajador_nombre'] ?? j['nombre'] ?? '')
            .toString()
            .trim();

    return TaTrabajador(
      id: (j['id'] as num).toInt(),
      codigo: codigo,
      nombreCompleto: nombre,
      kg: toDouble(j['kg'] ?? j['kilos'] ?? 0),
    );
  }
}
