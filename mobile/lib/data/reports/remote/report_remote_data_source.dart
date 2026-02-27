import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/network/api_client.dart';

class ReportRemoteDataSource {
  ReportRemoteDataSource(this._api);

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

  Future<List<Map<String, dynamic>>> fetchUserPickers({
    required List<String> roles,
  }) async {
    final resp = await _api.get('/users/pickers?roles=${roles.join(',')}');
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba lista de usuarios');
    }
    return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchReportes({
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
      return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
    }

    if (decoded is Map) {
      if (decoded['items'] is List) {
        final items = decoded['items'] as List;
        return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
      }
      if (decoded['data'] is List) {
        final items = decoded['data'] as List;
        return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
      }
    }

    throw Exception('Respuesta inválida (no lista)');
  }

  Future<Uint8List> fetchReportePdf(int reporteId) async {
    final resp = await _api.getRaw('/reportes/$reporteId/pdf');
    _api.throwIfHtml(resp, hint: 'PDF reportes');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return resp.bodyBytes;
  }

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

  Future<Map<String, dynamic>> openSaneamiento({
    required DateTime fecha,
    required String turno,
  }) async {
    final resp = await _api.get(
      '/reportes/saneamiento/open?turno=${Uri.encodeQueryComponent(turno)}&fecha=${_fmtFecha(fecha)}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida openSaneamiento');
    }
    final existente = decoded['existente'] == true;
    final reporte = decoded['reporte'];
    final reporteMap = reporte is Map ? reporte.cast<String, dynamic>() : null;
    final estado = reporteMap?['estado'];
    final id = reporteMap?['id'];
    debugPrint(
      '[TEMP] openSaneamiento response: existente=$existente, '
      'estado=$estado, id=$id',
    );
    return decoded.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> openApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final fechaLog = fecha == null
        ? 'null'
        : DateFormat('yyyy-MM-dd').format(fecha);
    debugPrint('[ApoyoHoras] openApoyoHoras fecha=$fechaLog turno=$turno');
    final query = <String, String>{
      'turno': turno,
      if (fecha != null) 'fecha': _fmtFecha(fecha),
      // ✅ sin create=0 aquí, porque este es el "open-or-create"
      // (si no existe, el backend lo crea)
    };

    final resp = await _api.get(
      '/reportes/apoyo-horas/open?${Uri(queryParameters: query).query}',
    );

    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida openApoyoHoras');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> checkApoyoHoras({
    DateTime? fecha,
    required String turno,
  }) async {
    final fechaLog = fecha == null
        ? 'null'
        : DateFormat('yyyy-MM-dd').format(fecha);
    debugPrint('[ApoyoHoras] checkApoyoHoras fecha=$fechaLog turno=$turno');
    final query = <String, String>{
      'turno': turno,
      'create': '0',
      if (fecha != null) 'fecha': _fmtFecha(fecha),
    };
    final resp = await _api.get(
      '/reportes/apoyo-horas/open?${Uri(queryParameters: query).query}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida: se esperaba mapa JSON.');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchApoyoHorasPendientes({
    required int hours,
    DateTime? fecha,
    String? turno,
  }) async {
    final fechaLog = fecha == null
        ? 'null'
        : DateFormat('yyyy-MM-dd').format(fecha);
    debugPrint(
      '[ApoyoHoras] fetchApoyoHorasPendientes fecha=$fechaLog turno=${turno ?? ''} hours=$hours',
    );
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

    return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchSaneamientoPendientes({
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

    return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchApoyoAreas() async {
    final resp = await _api.get('/areas?tipo=APOYO_HORAS');
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba una lista JSON.');
    }

    return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchApoyoLineas(int reporteId) async {
    final resp = await _api.get('/reportes/$reporteId/lineas');
    final decoded = _api.decodeJsonOrThrow(resp);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

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
    Map<String, dynamic> buildPayload() {
      final payload = <String, dynamic>{
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'horas': horas,
        'area_id': areaId,
      };
      if (trabajadorId != null) {
        payload['trabajador_id'] = trabajadorId;
      } else {
        final codigo = trabajadorCodigo?.trim();
        final nombre = trabajadorNombre?.trim();
        final documento = trabajadorDocumento?.trim();
        if (codigo != null && codigo.isNotEmpty) {
          payload['trabajador_codigo'] = codigo;
        }
        if (nombre != null && nombre.isNotEmpty) {
          payload['trabajador_nombre'] = nombre;
        }
        if (documento != null && documento.isNotEmpty) {
          payload['trabajador_documento'] = documento;
        }
      }
      payload.removeWhere((key, value) => value == null);
      return payload;
    }

    if (lineaId != null) {
      final payload = buildPayload();
      final resp = await _api.patch('/reportes/lineas/$lineaId', payload);
      _ensureSuccess(resp, hint: 'Actualizar línea apoyo');
      return lineaId;
    }
    final payload = buildPayload();

    final resp = await _api.post('/reportes/$reporteId/lineas', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final id = decoded is Map ? decoded['linea_id'] : null;
    return (id is num) ? id.toInt() : null;
  }

  Future<List<Map<String, dynamic>>> fetchSaneamientoLineas(
    int reporteId,
  ) async {
    final resp = await _api.get('/reportes/$reporteId/lineas');
    if (resp.statusCode != 200) {
      return [];
    }
    _api.throwIfHtml(resp, hint: 'Líneas saneamiento');
    final decoded = jsonDecode(resp.body);
    final items = (decoded is Map && decoded['items'] is List)
        ? decoded['items'] as List
        : <dynamic>[];

    return items.whereType<Map>().cast<Map<String, dynamic>>().toList();
  }

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
    if (lineaId != null) {
      final payload = <String, dynamic>{
        'trabajador_id': trabajadorId,
        'trabajador_codigo': trabajadorCodigo,
        'trabajador_documento': trabajadorDocumento,
        'trabajador_nombre': trabajadorNombre,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'horas': horas,
        'area_id': null,
        'labores': (labores == null || labores.trim().isEmpty)
            ? null
            : labores.trim(),
      }..removeWhere((key, value) => value == null);
      final resp = await _api.patch('/reportes/lineas/$lineaId', payload);
      _ensureSuccess(resp, hint: 'Actualizar línea saneamiento');
      return lineaId;
    }

    final payload = <String, dynamic>{
      'trabajador_id': trabajadorId,
      'trabajador_codigo': trabajadorCodigo,
      'trabajador_documento': trabajadorDocumento,
      'trabajador_nombre': trabajadorNombre,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'horas': horas,
      'area_id': null,
      'labores': (labores == null || labores.trim().isEmpty)
          ? null
          : labores.trim(),
    }..removeWhere((key, value) => value == null);

    final resp = await _api.post('/reportes/$reporteId/lineas', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final id = decoded is Map ? decoded['linea_id'] : null;
    return (id is num) ? id.toInt() : null;
  }

  Future<void> deleteReporteLinea(int lineaId) async {
    final resp = await _api.delete('/reportes/lineas/$lineaId');
    _ensureSuccess(resp, hint: 'Eliminar línea reporte');
  }

  Future<List<Map<String, dynamic>>> fetchConteoRapidoAreas() async {
    final resp = await _api.get('/areas/conteo-rapido');
    final decoded = _api.decodeJsonOrThrow(resp);
    final dataAreas = decoded as Map<String, dynamic>;
    final listAreas = (dataAreas['areas'] as List).cast<Map<String, dynamic>>();

    return listAreas;
  }

  Future<Map<String, dynamic>> openConteoRapido({
    required DateTime fecha,
    required String turno,
  }) async {
    final resp = await _api.get(
      '/reportes/conteo-rapido/open?turno=${Uri.encodeQueryComponent(turno)}&fecha=${_fmtFecha(fecha)}',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida openConteoRapido');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<int> saveConteoRapido({
    required DateTime fecha,
    required String turno,
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = {'fecha': _fmtFecha(fecha), 'turno': turno, 'items': items};

    final resp = await _api.post('/reportes/conteo-rapido', payload);
    final decoded = _api.decodeJsonOrThrow(resp);
    final reporteId = decoded['reporte_id'];
    if (reporteId is! num) {
      throw Exception('Respuesta invalida: falta reporte_id');
    }
    return reporteId.toInt();
  }

  Future<Map<String, dynamic>> startTrabajoAvance({
    required DateTime fecha,
    required String turno,
  }) async {
    final resp = await _api.post('/reportes/trabajo-avance/start', {
      'fecha': _fmtFecha(fecha),
      'turno': turno,
    });

    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida startTrabajoAvance');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchTrabajoAvanceResumen(int reporteId) async {
    final resp = await _api.get('/reportes/trabajo-avance/$reporteId/resumen');
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida trabajo avance resumen');
    }
    return decoded.cast<String, dynamic>();
  }

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

  Future<void> createTrabajoAvanceCuadrilla({
    required int reporteId,
    required String tipo,
    required String nombre,
    String? apoyoScope,
    int? apoyoDeCuadrillaId,
  }) async {
    final resp = await _api
        .post('/reportes/trabajo-avance/$reporteId/cuadrillas', {
          'tipo': tipo,
          'nombre': nombre,
          if (apoyoScope != null) 'apoyoScope': apoyoScope,
          'apoyoDeCuadrillaId': apoyoDeCuadrillaId,
        });
    _ensureSuccess(resp, hint: 'Crear cuadrilla trabajo avance');
    if (resp.body.trim().isEmpty) return;
    final decoded = jsonDecode(resp.body);
    if (decoded is Map && decoded['ok'] != true) {
      throw Exception('No se pudo crear cuadrilla');
    }
  }

  Future<Map<String, dynamic>> fetchTrabajoAvanceCuadrillaDetalle(
    int cuadrillaId,
  ) async {
    final resp = await _api.get(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId',
    );
    final decoded = _api.decodeJsonOrThrow(resp);
    if (decoded is! Map) {
      throw Exception('Respuesta inválida trabajo avance detalle');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<void> updateTrabajoAvanceCuadrilla({
    required int cuadrillaId,
    String? horaInicio,
    String? horaFin,
    required double produccionKg,
  }) async {
    final payload = {
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'produccion_kg': produccionKg,
    };
    debugPrint(
      'TA remote update cuadrilla PUT -> cuadrillaId=$cuadrillaId, payload=$payload',
    );
    final resp = await _api.put(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId',
      payload,
    );
    _ensureSuccess(resp, hint: 'Actualizar cuadrilla trabajo avance');
  }

  Future<void> addTrabajoAvanceTrabajador({
    required int cuadrillaId,
    required String q,
    String? codigo,
  }) async {
    final payload = <String, dynamic>{
      'q': q,
      if (codigo != null && codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
    };

    debugPrint(
      'TA remote add trabajador POST -> cuadrillaId=$cuadrillaId, '
      "q=${payload['q']}, codigo=${payload['codigo']}",
    );
    final resp = await _api.post(
      '/reportes/trabajo-avance/cuadrillas/$cuadrillaId/trabajadores',
      payload,
    );
    _ensureSuccess(resp, hint: 'Agregar trabajador trabajo avance');
  }

  Future<void> deleteTrabajoAvanceTrabajador(int trabajadorId) async {
    final resp = await _api.delete(
      '/reportes/trabajo-avance/trabajadores/$trabajadorId',
    );
    _ensureSuccess(resp, hint: 'Eliminar trabajador trabajo avance');
  }
}
