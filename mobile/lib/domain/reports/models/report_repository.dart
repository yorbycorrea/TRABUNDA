import 'dart:typed_data';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/features/reports/data/models/report_resumen.dart';

abstract class ReportRepository {
  Future<List<UserPickerItem>> fetchUserPickers({required List<String> roles});
  Future<List<ReportResumen>> fetchReportes({
    DateTime? fecha,
    String? turno,
    String? tipo,
    int? userId,
  });
  Future<ReportOpenInfo?> checkApoyoHoras({
    DateTime? fecha,
    required String turno,
  });

  Future<Uint8List> fetchReportePdf(int reporteId);
  Future<Uint8List> fetchConteoRapidoExcel(int reporteId);

  Future<int> createReporte({
    required DateTime fecha,
    required String turno,
    required String tipoReporte,
    int? areaId,
    String? observaciones,
  });

  Future<ReportOpenInfo> openSaneamiento({
    required DateTime fecha,
    required String turno,
  });

  Future<ReportOpenInfo> openApoyoHoras({
    DateTime? fecha,
    required String turno,
  });

  Future<List<ReportPendiente>> fetchApoyoHorasPendientes({
    required int hours,
    DateTime? fecha,
    String? turno,
  });

  Future<List<ReportPendiente>> fetchSaneamientoPendientes({
    required int hours,
    String? turno,
  });

  Future<List<ApoyoHorasArea>> fetchApoyoAreas();

  Future<List<ApoyoHorasLinea>> fetchApoyoLineas(int reporteId);

  Future<int?> upsertApoyoLinea({
    int? lineaId,
    required int reporteId,
    int? trabajadorId,
    String? trabajadorCodigo,
    String? trabajadorDocumento,
    String? trabajadorNombre,
    required String horaInicio,
    String? horaFin,
    double? horas,
    required int areaId,
  });

  Future<List<SaneamientoLinea>> fetchSaneamientoLineas(int reporteId);

  Future<int?> upsertSaneamientoLinea({
    int? lineaId,
    required int reporteId,
    required int trabajadorId,
    String? trabajadorCodigo,
    String? trabajadorDocumento,
    String? trabajadorNombre,
    required String horaInicio,
    String? horaFin,
    double? horas,
    String? labores,
  });

  Future<List<ConteoRapidoArea>> fetchConteoRapidoAreas();

  Future<ConteoRapidoOpenResult> openConteoRapido({
    required DateTime fecha,
    required String turno,
  });

  Future<int> saveConteoRapido({
    required DateTime fecha,
    required String turno,
    required List<ConteoRapidoItem> items,
  });

  Future<TrabajoAvanceStartResult> startTrabajoAvance({
    required DateTime fecha,
    required String turno,
  });

  Future<TrabajoAvanceResumen> fetchTrabajoAvanceResumen(int reporteId);

  Future<void> updateTrabajoAvanceHorario({
    required int reporteId,
    String? horaInicio,
    String? horaFin,
  });

  Future<void> createTrabajoAvanceCuadrilla({
    required int reporteId,
    required String tipo,
    required String nombre,
    int? apoyoDeCuadrillaId,
  });

  Future<TrabajoAvanceCuadrillaDetalle> fetchTrabajoAvanceCuadrillaDetalle(
    int cuadrillaId,
  );

  Future<void> updateTrabajoAvanceCuadrilla({
    required int cuadrillaId,
    String? horaInicio,
    String? horaFin,
    required double produccionKg,
  });

  Future<void> addTrabajoAvanceTrabajador({
    required int cuadrillaId,
    required String q,
    String? codigo,
  });

  Future<void> deleteTrabajoAvanceTrabajador(int trabajadorId);
}
