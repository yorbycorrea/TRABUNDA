import 'dart:convert';
import 'dart:typed_data';
import 'package:mobile/data/reports/remote/report_remote_data_source.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/models/report_repository.dart';
import 'package:mobile/features/reports/data/models/report_resumen.dart';
import 'package:mobile/features/trabajo_avance/models.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(ApiClient api) : _remote = ReportRemoteDataSource(api);

  final ReportRemoteDataSource _remote;

  String _fmtFecha(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  ReportPendiente _mapReportePendiente(
    Map<String, dynamic> m, {
    String? areaNombreOverride,
  }) {
    return ReportPendiente(
      reportId: (m['report_id'] as num?)?.toInt() ?? 0,
      fecha: (m['fecha'] ?? '').toString(),
      turno: (m['turno'] ?? '').toString(),
      creadoPorNombre: (m['creado_por_nombre'] ?? '').toString(),
      pendientes: (m['pendiente'] as num?)?.toInt() ?? 0,
      areaNombre: areaNombreOverride ?? (m['area_nombre'] ?? '').toString(),
    );
  }

  String _codigo5(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    return RegExp(r'^\d+$').hasMatch(raw) ? raw.padLeft(5, '0') : raw;
  }

  @override
  Future<List<UserPickerItem>> fetchUserPickers({
    required List<String> roles,
  }) async {
    final items = await _remote.fetchUserPickers(roles: roles);
    return items
        .map(
          (e) => UserPickerItem(
            id: (e['id'] as num).toInt(),
            nombre: (e['nombre'] ?? '').toString(),
            role: (e['role'] ?? e['codigo'] ?? '').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<List<ReportResumen>> fetchReportes({
    DateTime? fecha,
    String? turno,
    String? tipo,
    int? userId,
  }) async {
    final items = await _remote.fetchReportes(
      fecha: fecha,
      turno: turno,
      tipo: tipo,
      userId: userId,
    );
    return items.map(ReportResumen.fromJson).toList();
  }

  @override
  Future<Uint8List> fetchReportePdf(int reporteId) async {
    return _remote.fetchReportePdf(reporteId);
  }

  @override
  Future<Uint8List> fetchConteoRapidoExcel(int reporteId) async {
    return _remote.fetchConteoRapidoExcel(reporteId);
  }

  @override
  Future<int> createReporte({
    required DateTime fecha,
    required String turno,
    required String tipoReporte,
    int? areaId,
    String? observaciones,
  }) async {
    return _remote.createReporte(
      fecha: fecha,
      turno: turno,
      tipoReporte: tipoReporte,
      areaId: areaId,
      observaciones: observaciones,
    );
  }

  @override
  Future<ReportOpenInfo> openSaneamiento({
    required DateTime fecha,
    required String turno,
  }) async {
    final decoded = await _remote.openSaneamiento(fecha: fecha, turno: turno);
    final existente = decoded['existente'] == true;
    final allowCreate = decoded['allowCreate'];
    final allowCreateValue = allowCreate is bool ? allowCreate : true;
    if (!existente) {
      return ReportOpenInfo(
        id: 0,
        fecha: _fmtFecha(fecha),
        turno: turno,
        creadoPorNombre: '',
        allowCreate: allowCreateValue,
        estado: '',
      );
    }
    final repRaw = decoded['reporte'];
    if (repRaw is! Map) {
      throw Exception('Respuesta inválida: reporte no es mapa.');
    }

    final rep = repRaw.cast<String, dynamic>();

    return ReportOpenInfo(
      id: (rep['id'] as num).toInt(),
      fecha: (rep['fecha'] ?? _fmtFecha(fecha)).toString(),
      turno: (rep['turno'] ?? turno).toString(),
      creadoPorNombre: (rep['creado_por_nombre'] ?? '').toString(),
      allowCreate: allowCreateValue,
      estado: (rep['estado'] ?? '').toString(),
    );
  }

  @override
  Future<ReportOpenInfo> openApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final decoded = await _remote.openApoyoHoras(fecha: fecha, turno: turno);

    final rep = (decoded['reporte'] as Map).cast<String, dynamic>();
    final allowCreate = decoded['allowCreate'];
    final allowCreateValue = allowCreate is bool ? allowCreate : true;

    return ReportOpenInfo(
      id: (rep['id'] as num).toInt(),
      fecha: (rep['fecha'] ?? (fecha != null ? _fmtFecha(fecha) : ''))
          .toString(),
      turno: (rep['turno'] ?? turno).toString(),
      creadoPorNombre: (rep['creado_por_nombre'] ?? '').toString(),
      allowCreate: allowCreateValue,
      estado: (rep['estado'] ?? '').toString(),
    );
  }

  @override
  Future<ReportOpenInfo?> checkApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final decoded = await _remote.checkApoyoHoras(fecha: fecha, turno: turno);

    final existente = decoded['existente'] == true;
    if (!existente) {
      return null;
    }
    final repRaw = decoded['reporte'];
    if (repRaw is! Map) {
      throw Exception('Respuesta inválida: reporte no es mapa.');
    }
    final rep = repRaw.cast<String, dynamic>();
    final allowCreate = decoded['allowCreate'];
    final allowCreateValue = allowCreate is bool ? allowCreate : true;
    return ReportOpenInfo(
      id: (rep['id'] as num).toInt(),
      fecha: (rep['fecha'] ?? (fecha != null ? _fmtFecha(fecha) : ''))
          .toString(),
      turno: (rep['turno'] ?? turno).toString(),
      creadoPorNombre: (rep['creado_por_nombre'] ?? '').toString(),
      allowCreate: allowCreateValue,
      estado: (rep['estado'] ?? '').toString(),
    );
  }

  @override
  Future<List<ReportPendiente>> fetchApoyoHorasPendientes({
    required int hours,
    DateTime? fecha,
    String? turno,
  }) async {
    final items = await _remote.fetchApoyoHorasPendientes(
      hours: hours,
      fecha: fecha,
      turno: turno,
    );

    return items.map(_mapReportePendiente).toList();
  }

  @override
  Future<List<ReportPendiente>> fetchSaneamientoPendientes({
    required int hours,
    String? turno,
  }) async {
    final items = await _remote.fetchSaneamientoPendientes(
      hours: hours,
      turno: turno,
    );

    return items
        .map((m) => _mapReportePendiente(m, areaNombreOverride: ''))
        .toList();
  }

  @override
  Future<List<ApoyoHorasArea>> fetchApoyoAreas() async {
    final items = await _remote.fetchApoyoAreas();
    return items
        .map(
          (e) => ApoyoHorasArea(
            id: (e['id'] as num).toInt(),
            nombre: (e['nombre'] ?? '').toString(),
            activo: (e['activo'] as num?)?.toInt() ?? 1,
          ),
        )
        .where((a) => a.activo == 1)
        .toList();
  }

  @override
  Future<List<ApoyoHorasLinea>> fetchApoyoLineas(int reporteId) async {
    final items = await _remote.fetchApoyoLineas(reporteId);

    return items
        .map(
          (it) => ApoyoHorasLinea(
            id: (it['id'] as num?)?.toInt(),
            trabajadorId: (it['trabajador_id'] as num?)?.toInt(),
            trabajadorCodigo: _codigo5(it['trabajador_codigo']),
            trabajadorNombre: (it['trabajador_nombre'] ?? '').toString(),
            trabajadorDocumento: (it['trabajador_documento'] ?? '').toString(),
            areaId: (it['area_id'] as num?)?.toInt(),
            areaNombre: (it['area_nombre'] ?? '').toString(),
            horaInicio: it['hora_inicio']?.toString(),
            horaFin: it['hora_fin']?.toString(),
            horas: (it['horas'] is num)
                ? (it['horas'] as num).toDouble()
                : null,
          ),
        )
        .toList();
  }

  @override
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
  }) async {
    return _remote.upsertApoyoLinea(
      lineaId: lineaId,
      reporteId: reporteId,
      trabajadorId: trabajadorId,
      trabajadorCodigo: trabajadorCodigo,
      trabajadorDocumento: trabajadorDocumento,
      trabajadorNombre: trabajadorNombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      horas: horas,
      areaId: areaId,
    );
  }

  @override
  Future<List<SaneamientoLinea>> fetchSaneamientoLineas(int reporteId) async {
    final items = await _remote.fetchSaneamientoLineas(reporteId);

    return items
        .map(
          (it) => SaneamientoLinea(
            id: (it['id'] as num?)?.toInt(),
            trabajadorId: (it['trabajador_id'] as num?)?.toInt(),
            trabajadorCodigo: (it['trabajador_codigo'] ?? '').toString(),
            trabajadorNombre: (it['trabajador_nombre'] ?? '').toString(),
            horaInicio: it['hora_inicio']?.toString(),
            horaFin: it['hora_fin']?.toString(),
            horas: (it['horas'] is num)
                ? (it['horas'] as num).toDouble()
                : null,
            labores: (it['labores'] ?? '').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<int?> upsertSaneamientoLinea({
    int? lineaId,
    required int reporteId,
    required int trabajadorId,
    String? trabajadorCodigo,
    String? trabajadorDocumento,
    String? trabajadorNombre,
    String? horaInicio,
    String? horaFin,
    double? horas,
    String? labores,
  }) async {
    return _remote.upsertSaneamientoLinea(
      lineaId: lineaId,
      reporteId: reporteId,
      trabajadorId: trabajadorId,
      trabajadorCodigo: trabajadorCodigo,
      trabajadorDocumento: trabajadorDocumento,
      trabajadorNombre: trabajadorNombre,
      horaInicio: (lineaId == null) ? horaInicio : null,
      horaFin: horaFin,
      horas: horas,
      labores: labores,
    );
  }

  @override
  Future<List<ConteoRapidoArea>> fetchConteoRapidoAreas() async {
    final listAreas = await _remote.fetchConteoRapidoAreas();

    return listAreas
        .map(
          (j) => ConteoRapidoArea(
            id: (j['id'] as num).toInt(),
            nombre: (j['nombre'] ?? '').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<ConteoRapidoOpenResult> openConteoRapido({
    required DateTime fecha,
    required String turno,
  }) async {
    final decoded = await _remote.openConteoRapido(fecha: fecha, turno: turno);

    final existente = decoded['existente'] == true;
    final rep = (decoded['reporte'] as Map).cast<String, dynamic>();
    final id = (rep['id'] as num).toInt();

    final items = (decoded['items'] is List)
        ? (decoded['items'] as List)
              .whereType<Map>()
              .map(
                (e) => ConteoRapidoItem(
                  areaId: (e['area_id'] as num).toInt(),
                  cantidad: (e['cantidad'] is num)
                      ? (e['cantidad'] as num).toInt()
                      : int.tryParse('${e['cantidad']}') ?? 0,
                ),
              )
              .toList()
        : <ConteoRapidoItem>[];

    return ConteoRapidoOpenResult(
      existente: existente,
      reporteId: id,
      items: items,
    );
  }

  @override
  Future<int> saveConteoRapido({
    required DateTime fecha,
    required String turno,
    required List<ConteoRapidoItem> items,
  }) async {
    return _remote.saveConteoRapido(
      fecha: fecha,
      turno: turno,
      items: items
          .map((a) => {'area_id': a.areaId, 'cantidad': a.cantidad})
          .toList(),
    );
  }

  @override
  Future<TrabajoAvanceStartResult> startTrabajoAvance({
    required DateTime fecha,
    required String turno,
  }) async {
    final decoded = await _remote.startTrabajoAvance(
      fecha: fecha,
      turno: turno,
    );
    final rep = (decoded['reporte'] as Map).cast<String, dynamic>();
    return TrabajoAvanceStartResult(
      existente: decoded['existente'] == true,
      reporte: TrabajoAvanceReporte(
        id: (rep['id'] as num).toInt(),
        estado: (rep['estado'] ?? '').toString(),
        horaInicio: rep['hora_inicio']?.toString(),
        horaFin: rep['hora_fin']?.toString(),
      ),
    );
  }

  @override
  Future<TrabajoAvanceResumen> fetchTrabajoAvanceResumen(int reporteId) async {
    final decoded = await _remote.fetchTrabajoAvanceResumen(reporteId);
    final rep = (decoded['reporte'] as Map?)?.cast<String, dynamic>();
    final tot = (decoded['totales'] as Map<String, dynamic>);
    final cuad = (decoded['cuadrillas'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return TrabajoAvanceResumen(
      reporte: rep == null
          ? null
          : TrabajoAvanceReporte(
              id: (rep['id'] as num).toInt(),
              estado: (rep['estado'] ?? '').toString(),
              horaInicio: rep['hora_inicio']?.toString(),
              horaFin: rep['hora_fin']?.toString(),
            ),
      totales: {
        'RECEPCION': toDouble(tot['RECEPCION']),
        'FILETEADO': toDouble(tot['FILETEADO']),
        'APOYO_RECEPCION': toDouble(tot['APOYO_RECEPCION']),
      },
      cuadrillas: cuad.map(TaCuadrilla.fromJson).toList(),
    );
  }

  @override
  Future<void> updateTrabajoAvanceHorario({
    required int reporteId,
    String? horaInicio,
    String? horaFin,
  }) async {
    await _remote.updateTrabajoAvanceHorario(
      reporteId: reporteId,
      horaInicio: horaInicio,
      horaFin: horaFin,
    );
  }

  @override
  Future<void> createTrabajoAvanceCuadrilla({
    required int reporteId,
    required String tipo,
    required String nombre,
    int? apoyoDeCuadrillaId,
  }) async {
    await _remote.createTrabajoAvanceCuadrilla(
      reporteId: reporteId,
      tipo: tipo,
      nombre: nombre,
      apoyoDeCuadrillaId: apoyoDeCuadrillaId,
    );
  }

  @override
  Future<TrabajoAvanceCuadrillaDetalle> fetchTrabajoAvanceCuadrillaDetalle(
    int cuadrillaId,
  ) async {
    final decoded = await _remote.fetchTrabajoAvanceCuadrillaDetalle(
      cuadrillaId,
    );

    final cuadrillaRaw = decoded['cuadrilla'];
    if (cuadrillaRaw is! Map) {
      throw Exception('Respuesta inválida: cuadrilla no es mapa.');
    }

    return TrabajoAvanceCuadrillaDetalle(
      cuadrilla: TaCuadrilla.fromJson(cuadrillaRaw.cast<String, dynamic>()),
      trabajadores: (decoded['trabajadores'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(TaTrabajador.fromJson)
          .toList(),
    );
  }

  @override
  Future<void> updateTrabajoAvanceCuadrilla({
    required int cuadrillaId,
    String? horaInicio,
    String? horaFin,
    required double produccionKg,
  }) async {
    await _remote.updateTrabajoAvanceCuadrilla(
      cuadrillaId: cuadrillaId,
      horaInicio: horaInicio,
      horaFin: horaFin,
      produccionKg: produccionKg,
    );
  }

  @override
  Future<void> addTrabajoAvanceTrabajador({
    required int cuadrillaId,
    required String codigo,
  }) async {
    await _remote.addTrabajoAvanceTrabajador(
      cuadrillaId: cuadrillaId,
      codigo: codigo,
    );
  }

  @override
  Future<void> deleteTrabajoAvanceTrabajador(int trabajadorId) async {
    await _remote.deleteTrabajoAvanceTrabajador(trabajadorId);
  }
}
