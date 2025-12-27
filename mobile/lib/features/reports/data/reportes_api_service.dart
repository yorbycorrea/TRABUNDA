import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';

class ReportesApiService {
  ReportesApiService(this._api);
  final ApiClient _api;

  Future<int> crearCabecera({
    required String fecha,
    required String turno,
    required String tipoReporte,
    required int areaId,
    String? observaciones,
  }) async {
    final http.Response resp = await _api.post('/reportes', {
      'fecha': fecha,
      'turno': turno,
      'tipo_reporte': tipoReporte,
      'area_id': areaId,
      'observaciones': observaciones,
    });

    final Map<String, dynamic> data = resp.body.isEmpty
        ? {}
        : (jsonDecode(resp.body) as Map<String, dynamic>);

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      final msg = (data['error'] ?? 'Error creando reporte').toString();
      throw Exception(msg);
    }

    final id = data['reporte_id'];
    if (id is! int) throw Exception('Respuesta invalida: falta reporte_id');
    return id;
  }

  Future<int> crearDetalle({
    required int reporteId,
    required int trabajarId,
    String? horaInicio,
    String? horaFin,
    String? tarea,
    num? horas,
    num? kilos,
    int? conteo,
  }) async {
    final http.Response resp = await _api
        .post('/reportes/$reporteId/detalles', {
          'trabajador_id': trabajarId,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'tarea': tarea,
          'horas': horas,
          'kilos': kilos,
          'conteo': conteo,
        });

    final Map<String, dynamic> data = resp.body.isEmpty
        ? {}
        : (jsonDecode(resp.body) as Map<String, dynamic>);

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      final msg = (data['error'] ?? 'Error creando detalle').toString();
      throw Exception(msg);
    }

    final id = data['detalle_id'];
    if (id is! int) return -1;
    return id;
  }
}
