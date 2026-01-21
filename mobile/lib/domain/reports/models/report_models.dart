import 'package:mobile/features/trabajo_avance/models.dart';

class UserPickerItem {
  final int id;
  final String nombre;
  final String role;

  const UserPickerItem({
    required this.id,
    required this.nombre,
    required this.role,
  });
}

class ReportOpenInfo {
  final int id;
  final String fecha;
  final String turno;
  final String creadoPorNombre;

  const ReportOpenInfo({
    required this.id,
    required this.fecha,
    required this.turno,
    required this.creadoPorNombre,
  });
}

class ReportPendiente {
  final int reportId;
  final String fecha;
  final String turno;
  final String creadoPorNombre;
  final int pendientes;
  final String areaNombre;

  const ReportPendiente({
    required this.reportId,
    required this.fecha,
    required this.turno,
    required this.creadoPorNombre,
    required this.pendientes,
    required this.areaNombre,
  });
}

class ApoyoHorasArea {
  final int id;
  final String nombre;
  final int activo;

  const ApoyoHorasArea({
    required this.id,
    required this.nombre,
    required this.activo,
  });
}

class ApoyoHorasLinea {
  final int? id;
  final int? trabajadorId;
  final String trabajadorCodigo;
  final String trabajadorNombre;
  final int? areaId;
  final String? areaNombre;
  final String? horaInicio;
  final String? horaFin;
  final double? horas;

  const ApoyoHorasLinea({
    required this.id,
    required this.trabajadorId,
    required this.trabajadorCodigo,
    required this.trabajadorNombre,
    required this.areaId,
    required this.areaNombre,
    required this.horaInicio,
    required this.horaFin,
    required this.horas,
  });
}

class SaneamientoLinea {
  final int? id;
  final int? trabajadorId;
  final String trabajadorCodigo;
  final String trabajadorNombre;
  final String? horaInicio;
  final String? horaFin;
  final double? horas;
  final String labores;

  const SaneamientoLinea({
    required this.id,
    required this.trabajadorId,
    required this.trabajadorCodigo,
    required this.trabajadorNombre,
    required this.horaInicio,
    required this.horaFin,
    required this.horas,
    required this.labores,
  });
}

class ConteoRapidoArea {
  final int id;
  final String nombre;

  const ConteoRapidoArea({required this.id, required this.nombre});
}

class ConteoRapidoItem {
  final int areaId;
  final int cantidad;

  const ConteoRapidoItem({required this.areaId, required this.cantidad});
}

class ConteoRapidoOpenResult {
  final bool existente;
  final int reporteId;
  final List<ConteoRapidoItem> items;

  const ConteoRapidoOpenResult({
    required this.existente,
    required this.reporteId,
    required this.items,
  });
}

class TrabajoAvanceReporte {
  final int id;
  final String estado;
  final String? horaInicio;
  final String? horaFin;

  const TrabajoAvanceReporte({
    required this.id,
    required this.estado,
    required this.horaInicio,
    required this.horaFin,
  });
}

class TrabajoAvanceStartResult {
  final bool existente;
  final TrabajoAvanceReporte reporte;

  const TrabajoAvanceStartResult({
    required this.existente,
    required this.reporte,
  });
}

class TrabajoAvanceResumen {
  final TrabajoAvanceReporte? reporte;
  final Map<String, double> totales;
  final List<TaCuadrilla> cuadrillas;

  const TrabajoAvanceResumen({
    required this.reporte,
    required this.totales,
    required this.cuadrillas,
  });
}

class TrabajoAvanceCuadrillaDetalle {
  final TaCuadrilla cuadrilla;
  final List<TaTrabajador> trabajadores;

  const TrabajoAvanceCuadrillaDetalle({
    required this.cuadrilla,
    required this.trabajadores,
  });
}
