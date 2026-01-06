import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/menu/presentation/pages/report_apoyos_horas_page.dart';
import 'package:mobile/features/state_apoyo_horas.dart'; // <-- tu pantalla pendientes

class ApoyosHorasEntryPage extends StatefulWidget {
  const ApoyosHorasEntryPage({
    super.key,
    required this.api,
    required this.turno,
  });

  final ApiClient api;
  final String turno;

  @override
  State<ApoyosHorasEntryPage> createState() => _ApoyosHorasEntryPageState();
}

class _ApoyosHorasEntryPageState extends State<ApoyosHorasEntryPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
  }

  DateTime _parseFecha(String? s) {
    if (s == null || s.trim().isEmpty) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _decidirRuta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Ver si hay pendientes (si hay -> mostrar pantalla de pendientes)
      final pendResp = await widget.api.get(
        '/reportes/apoyo-horas/pendientes?hours=24',
      );

      final pendBody = pendResp.body.trimLeft();
      if (pendBody.startsWith('<!DOCTYPE') || pendBody.startsWith('<html')) {
        throw Exception(
          'Backend devolvió HTML en pendientes. Revisa baseUrl/ruta.\nHTTP ${pendResp.statusCode}',
        );
      }

      final pendDecoded = jsonDecode(pendResp.body);
      if (pendResp.statusCode != 200) {
        final msg = (pendDecoded is Map && pendDecoded['error'] != null)
            ? pendDecoded['error'].toString()
            : 'Error cargando pendientes (HTTP ${pendResp.statusCode})';
        throw Exception(msg);
      }

      final items = (pendDecoded is Map && pendDecoded['items'] is List)
          ? (pendDecoded['items'] as List)
          : <dynamic>[];

      if (!mounted) return;

      // ✅ Si hay al menos un reporte con pendientes => ir a TU pantalla especial
      if (items.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApoyosHorasHomePage(api: widget.api, turno: widget.turno),
          ),
        );
        return;
      }

      // 2) Si NO hay pendientes, crear/obtener reporte ABIERTO y entrar directo al formulario
      final openResp = await widget.api.get(
        '/reportes/apoyo-horas/open?turno=${Uri.encodeQueryComponent(widget.turno)}',
      );

      final openBody = openResp.body.trimLeft();
      if (openBody.startsWith('<!DOCTYPE') || openBody.startsWith('<html')) {
        throw Exception(
          'Backend devolvió HTML en open. Revisa baseUrl/ruta.\nHTTP ${openResp.statusCode}',
        );
      }

      final openDecoded = jsonDecode(openResp.body);
      if (openResp.statusCode < 200 || openResp.statusCode >= 300) {
        final msg = (openDecoded is Map && openDecoded['error'] != null)
            ? openDecoded['error'].toString()
            : 'Error abriendo reporte (HTTP ${openResp.statusCode})';
        throw Exception(msg);
      }

      final reporte = (openDecoded is Map && openDecoded['reporte'] is Map)
          ? (openDecoded['reporte'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final reporteId = (reporte['id'] as num?)?.toInt() ?? 0;
      final fecha = _parseFecha(reporte['fecha']?.toString());
      final turno = (reporte['turno'] ?? widget.turno).toString();
      final planillero = (reporte['creado_por_nombre'] ?? '').toString();

      if (reporteId <= 0) {
        throw Exception('open devolvió un reporte inválido (id=0).');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ApoyosHorasBackendPage(
            api: widget.api,
            reporteId: reporteId,
            fecha: fecha,
            turno: turno,
            planillero: planillero,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apoyos por horas')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 10),
                  const Text('No se pudo abrir el flujo'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _error ?? 'Error desconocido',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _decidirRuta,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
      ),
    );
  }
}
