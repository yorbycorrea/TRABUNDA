import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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

  Future<void> descargarExcel(int reporteId) async {
    final resp = await _api.get('/reportes/conteo-rapido/$reporteId/excel');

    // DEBUG útil (déjalo mientras pruebas)
    final ct = resp.headers['content-type'] ?? '';
    final preview = String.fromCharCodes(resp.bodyBytes.take(120));
    // ignore: avoid_print
    print(
      'EXCEL status=${resp.statusCode} content-type=$ct bytes=${resp.bodyBytes.length}',
    );
    // ignore: avoid_print
    print('EXCEL preview=$preview');

    if (resp.statusCode != 200) {
      // normalmente aquí viene JSON con {error: "..."}
      throw Exception('Error ${resp.statusCode}: $preview');
    }

    // Validación rápida: un .xlsx real (ZIP) empieza con "PK"
    final bytes = resp.bodyBytes;
    final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!isZip) {
      throw Exception(
        'La respuesta no es un .xlsx válido. content-type=$ct preview=$preview',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte_conteo_$reporteId.xlsx');

    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }
}
