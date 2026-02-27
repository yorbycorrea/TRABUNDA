class ReportResumen {
  final int id;
  final DateTime fecha;
  final String turno; // "Dia" | "Noche"
  final String planillero; // creado_por_nombre
  final String? tipoReporte; // "APOYO_HORAS" | ...
  final String? areaNombre; // puede venir null
  final String? observaciones;

  ReportResumen({
    required this.id,
    required this.fecha,
    required this.turno,
    required this.planillero,
    required this.tipoReporte,
    required this.areaNombre,
    required this.observaciones,
  });

  factory ReportResumen.fromJson(Map<String, dynamic> json) {
    return ReportResumen(
      id: (json['id'] as num).toInt(),
      fecha: DateTime.parse(json['fecha'].toString()),
      turno: json['turno']?.toString() ?? '',
      planillero: json['creado_por_nombre']?.toString() ?? '',
      tipoReporte: json['tipo_reporte']?.toString(),
      areaNombre: json['area_nombre']?.toString(),
      observaciones: json['observaciones']?.toString(),
    );
  }
}
