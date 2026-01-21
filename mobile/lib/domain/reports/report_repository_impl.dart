import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/models/report_repository.dart';
import 'package:mobile/features/reports/data/models/report_resumen.dart';
import 'package:mobile/features/trabajo_avance/models.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._api);

  final ApiClient _api;

  void _ensureSuccess(dynamic resp, {String? hint}) {
    _api.throwIfHtml(resp, hint: hint);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  String _fmtFecha(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Future<List<UserPickerItem>> fetchUserPickers({
    required List<String> roles,
  }) async {
    final resp = await _api.get('/users/pickers?roles=${roles.join(',')}');
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba lista de usuarios');
    }
    return decoded
        .whereType<Map>()
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
    final params = <String, String>{};
    if (fecha != null) params['fecha'] = _fmtFecha(fecha);
    if (turno != null && turno.isNotEmpty) params['turno'] = turno;
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    if (userId != null) params['user_id'] = userId.toString();

    final path = params.isEmpty
        ? '/reportes'
        : '/reportes?${Uri(queryParameters: params).query}';

    final resp = await _api.get(path);
    final decoded = _api.decodeJsonOrThrow(resp);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ReportResumen.fromJson)
          .toList();
    }

    if (decoded is Map) {
      if (decoded['items'] is List) {
        final items = decoded['items'] as List;
        return items
            .whereType<Map<String, dynamic>>()
            .map(ReportResumen.fromJson)
            .toList();
      }
      if (decoded['data'] is List) {
        final items = decoded['data'] as List;
        return items
            .whereType<Map<String, dynamic>>()
            .map(ReportResumen.fromJson)
            .toList();
      }
    }

    throw Exception('Respuesta inválida (no lista)');
  }

  @override
  Future<Uint8List> fetchReportePdf(int reporteId) async {
    final resp = await _api.getRaw('/reportes/$reporteId/pdf');
    _api.throwIfHtml(resp, hint: 'PDF reportes');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return resp.bodyBytes;
  }

  @override
  Future<Uint8List> fetchConteoRapidoExcel(int reporteId) async {
    final resp = await _api.get('/reportes/conteo-rapido/$reporteId/excel');
    if (resp.statusCode != 200) {
      final preview = String.fromCharCodes(resp.bodyBytes.take(120));
      throw Exception('Error ${resp.statusCode}: $preview');
    }

    final bytes = resp.bodyBytes;
    final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!isZip) {
      final ct = resp.headers['content-type'] ?? '';
      final preview = String.fromCharCodes(resp.bodyBytes.take(120));
      throw Exception(
        'La respuesta no es un .xlsx válido. content-type=$ct preview=$preview',
      );
    }

    return bytes;
  }

  @override
  Future<int> createReporte({
    required DateTime fecha,
    required String turno,
    required String tipoReporte,
    int? areaId,
    String? observaciones,
  }) async {
    final resp = await _api.post('/reportes', {
      'fecha': _fmtFecha(fecha),
      'turno': turno,
      'tipo_reporte': tipoReporte,
      'area_id': areaId,
      'observaciones': observaciones,
    });

    final decoded = _api.decodeJsonOrThrow(resp);
    final id = decoded is Map ? decoded['reporte_id'] : null;
    if (id is! num) throw Exception('Respuesta invalida: falta reporte_id');
    return id.toInt();
  }

  @override
  Future<ReportOpenInfo> openSaneamiento({
    required DateTime fecha,
    required String turno,
  }) async {
    final resp = await _api.get(
      '/reportes/saneamiento/open?turno=${Uri.encodeQueryComponent(turno)}&fecha=${_fmtFecha(fecha)}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    final rep = (decoded['reporte'] as Map).cast<String, dynamic>();
    return ReportOpenInfo(
      id: (rep['id'] as num).toInt(),
      fecha: (rep['fecha'] ?? _fmtFecha(fecha)).toString(),
      turno: (rep['turno'] ?? turno).toString(),
      creadoPorNombre: (rep['creado_por_nombre'] ?? '').toString(),
    );
  }

  @override
  Future<ReportOpenInfo> openApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final query = <String, String>{
      'turno': turno,
      if (fecha != null) 'fecha': _fmtFecha(fecha),
    };
    final resp = await _api.get(
      '/reportes/apoyo-horas/open?${Uri(queryParameters: query).query}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    final rep = (decoded['reporte'] as Map).cast<String, dynamic>();
    return ReportOpenInfo(
      id: (rep['id'] as num).toInt(),
      fecha: (rep['fecha'] ?? (fecha != null ? _fmtFecha(fecha) : ''))
          .toString(),
      turno: (rep['turno'] ?? turno).toString(),
      creadoPorNombre: (rep['creado_por_nombre'] ?? '').toString(),
    );
  }

  @override
  Future<List<ReportPendiente>> fetchApoyoHorasPendientes({
    required int hours,
    DateTime? fecha,
    String? turno,
  }) async {
    final params = <String, String>{'hours': hours.toString()};
    if (fecha != null) params['fecha'] = _fmtFecha(fecha);
    if (turno != null && turno.isNotEmpty) params['turno'] = turno;

    final resp = await _api.get(
      '/reportes/apoyo-horas/pendientes?${Uri(queryParameters: params).query}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items
        .whereType<Map>()
        .map(
          (m) => ReportPendiente(
            reportId: (m['report_id'] as num?)?.toInt() ?? 0,
            fecha: (m['fecha'] ?? '').toString(),
            turno: (m['turno'] ?? '').toString(),
            creadoPorNombre: (m['creado_por_nombre'] ?? '').toString(),
            pendientes: (m['pendiente'] as num?)?.toInt() ?? 0,
            areaNombre: (m['area_nombre'] ?? '').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<List<ReportPendiente>> fetchSaneamientoPendientes({
    required int hours,
    String? turno,
  }) async {
    final params = <String, String>{'hours': hours.toString()};
    if (turno != null && turno.isNotEmpty) {
      params['turno'] = turno;
    }

    final resp = await _api.get(
      '/reportes/saneamiento/pendientes?${Uri(queryParameters: params).query}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items
        .whereType<Map>()
        .map(
          (m) => ReportPendiente(
            reportId: (m['report_id'] as num?)?.toInt() ?? 0,
            fecha: (m['fecha'] ?? '').toString(),
            turno: (m['turno'] ?? '').toString(),
            creadoPorNombre: (m['creado_por_nombre'] ?? '').toString(),
            pendientes: (m['pendiente'] as num?)?.toInt() ?? 0,
            areaNombre: '',
          ),
        )
        .toList();
  }

  @override
  Future<List<ApoyoHorasArea>> fetchApoyoAreas() async {
    final resp = await _api.get('/areas?tipo=APOYO_HORAS');
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba una lista JSON.');
    }

    return decoded
        .whereType<Map>()
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
    final resp = await _api.get('/reportes/$reporteId/lineas');
    final decoded = _api.decodeJsonOrThrow(resp);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items
        .whereType<Map>()
        .map(
          (it) => ApoyoHorasLinea(
            id: (it['id'] as num?)?.toInt(),
            trabajadorId: (it['trabajador_id'] as num?)?.toInt(),
            trabajadorCodigo: (it['trabajador_codigo'] ?? '').toString(),
            trabajadorNombre: (it['trabajador_nombre'] ?? '').toString(),
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
    required int trabajadorId,
    required String horaInicio,
    String? horaFin,
    double? horas,
    required int areaId,
  }) async {
    final payload = <String, dynamic>{
      'trabajador_id': trabajadorId,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'horas': horas,
      'area_id': areaId,
    };

    if (lineaId != null) {
      final resp = await _api.patch('/reportes/lineas/$lineaId', payload);
      _ensureSuccess(resp, hint: 'Actualizar línea apoyo');
      return lineaId;
    }

    final resp = await _api.post('/reportes/$reporteId/lineas', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final id = decoded is Map ? decoded['linea_id'] : null;
    return (id is num) ? id.toInt() : null;
  }

  @override
  Future<List<SaneamientoLinea>> fetchSaneamientoLineas(int reporteId) async {
    final resp = await _api.get('/reportes/$reporteId/lineas');
    if (resp.statusCode != 200) {
      return [];
    }
    _api.throwIfHtml(resp, hint: 'Líneas saneamiento');
    final decoded = jsonDecode(resp.body);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items
        .whereType<Map>()
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
    required String horaInicio,
    String? horaFin,
    double? horas,
    String? labores,
  }) async {
    final payload = <String, dynamic>{
      'trabajador_id': trabajadorId,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'horas': horas,
      'area_id': null,
      'labores': (labores == null || labores.trim().isEmpty)
          ? null
          : labores.trim(),
    };

    if (lineaId != null) {
      final resp = await _api.patch('/reportes/lineas/$lineaId', payload);
      _ensureSuccess(resp, hint: 'Actualizar línea saneamiento');
      return lineaId;
    }

    final resp = await _api.post('/reportes/$reporteId/lineas', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final id = decoded is Map ? decoded['linea_id'] : null;
    return (id is num) ? id.toInt() : null;
  }

  @override
  Future<List<ConteoRapidoArea>> fetchConteoRapidoAreas() async {
    final resp = await _api.get('/areas/conteo-rapido');
    final decoded = _api.decodeJsonOrThrow(resp);
    final dataAreas = decoded as Map<String, dynamic>;
    final listAreas = (dataAreas['areas'] as List).cast<Map<String, dynamic>>();

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
    final resp = await _api.get(
      '/reportes/conteo-rapido/open?turno=${Uri.encodeQueryComponent(turno)}&fecha=${_fmtFecha(fecha)}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
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
    final payload = {
      'fecha': _fmtFecha(fecha),
      'turno': turno,
      'items': items
          .map((a) => {'area_id': a.areaId, 'cantidad': a.cantidad})
          .toList(),
    };

    final resp = await _api.post('/reportes/conteo-rapido', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final reporteId = decoded['reporte_id'];
    if (reporteId is! num) {
      throw Exception('Respuesta invalida: falta reporte_id');
    }
    return reporteId.toInt();
  }

  @override
  Future<TrabajoAvanceStartResult> startTrabajoAvance({
    required DateTime fecha,
    required String turno,
  }) async {
    final resp = await _api.post('/reportes/trabajo-avance/start', {
      'fecha': _fmtFecha(fecha),
      'turno': turno,
    });

    final decoded = _api.decodeJsonOrThrow(resp);
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
    final resp = await _api.get('/reportes/trabajo-avance/$reporteId/resumen');
    final decoded = _api.decodeJsonOrThrow(resp);
    final rep = (decoded['reporte'] as Map?)?.cast<String, dynamic>();
    final tot = (decoded['totales'] as Map<String, dynamic>);
    final cuad = (decoded['cuadrillas'] as List).cast<Map<String, dynamic>>();

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
    final resp = await _api.put('/reportes/trabajo-avance/$reporteId', {
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
    });
    _ensureSuccess(resp, hint: 'Actualizar horario trabajo avance');
  }

  @override
  Future<void> createTrabajoAvanceCuadrilla({
    required int reporteId,
    required String tipo,
    required String nombre,
    int? apoyoDeCuadrillaId,
  }) async {
    final resp = await _api.post(
      '/reportes/trabajo-avance/$reporteId/cuadrillas',
      {
        'tipo': tipo,
        'nombre': nombre,
        'apoyoDeCuadrillaId': apoyoDeCuadrillaId,
      },
    );
    _ensureSuccess(resp, hint: 'Crear cuadrilla trabajo avance');
    if (resp.body.trim().isEmpty) return;
    final decoded = jsonDecode(resp.body);
    if (decoded is Map && decoded['ok'] != true) {
      throw Exception('No se pudo crear cuadrilla');
    }
  }

  @override
  Future<TrabajoAvanceCuadrillaDetalle> fetchTrabajoAvanceCuadrillaDetalle(
    int cuadrillaId,
  ) async {
    final resp = await _api.get(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId',
    );
    final decoded = _api.decodeJsonOrThrow(resp);

    return TrabajoAvanceCuadrillaDetalle(
      cuadrilla: TaCuadrilla.fromJson(decoded['cuadrilla']),
      trabajadores: (decoded['trabajadores'] as List)
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
    final resp = await _api.put(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId',
      {
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'produccion_kg': produccionKg,
      },
    );
    _ensureSuccess(resp, hint: 'Actualizar cuadrilla trabajo avance');
  }

  @override
  Future<void> addTrabajoAvanceTrabajador({
    required int cuadrillaId,
    required String codigo,
  }) async {
    final resp = await _api.post(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId/trabajadores',
      {'codigo': codigo},
    );
    _ensureSuccess(resp, hint: 'Agregar trabajador trabajo avance');
  }

  @override
  Future<void> deleteTrabajoAvanceTrabajador(int trabajadorId) async {
    final resp = await _api.delete(
      '/reportes/trabajo-avance/trabajadores/$trabajadorId',
    );
    _ensureSuccess(resp, hint: 'Eliminar trabajador trabajo avance');
  }
}
