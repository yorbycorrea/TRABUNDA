//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/menu/presentation/pages/report_apoyos_horas_page.dart';
import 'package:mobile/features/state_apoyo_horas.dart';
import 'package:mobile/data/auth/auth_repository_impl.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

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
  DateTime? _fechaSel;

  late final FetchApoyoHorasPendientes _fetchApoyoHorasPendientes;
  late final OpenApoyoHorasReport _openApoyoHorasReport;

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _fetchApoyoHorasPendientes = FetchApoyoHorasPendientes(repository);
    _openApoyoHorasReport = OpenApoyoHorasReport(repository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
  }

  DateTime _parseFecha(String? s) {
    if (s == null || s.trim().isEmpty) {
      return _fechaSel ?? DateTime.now();
    }
    try {
      return DateTime.parse(s);
    } catch (_) {
      return _fechaSel ?? DateTime.now();
    }
  }

  Future<DateTime?> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSel ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _fechaSel = picked);
    }
    return picked;
  }

  Future<void> _decidirRuta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _fetchApoyoHorasPendientes.call(hours: 24);

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

      final fechaSeleccionada = _fechaSel ?? await _pickFecha();

      if (fechaSeleccionada == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Debes seleccionar una fecha para continuar.';
        });
        return;
      }

      final reporte = await _openApoyoHorasReport.call(
        turno: widget.turno,
        fecha: fechaSeleccionada,
      );

      if (reporte.id <= 0) {
        throw Exception('open devolvió un reporte inválido (id=0).');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ApoyosHorasBackendPage(
            api: widget.api,
            reporteId: reporte.id,
            fecha: _parseFecha(reporte.fecha),
            turno: reporte.turno,
            planillero: reporte.creadoPorNombre,
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
