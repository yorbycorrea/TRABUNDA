//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/domain/reports/models/report_repository.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/menu/presentation/pages/saneamiento_backend_page.dart';
import 'package:mobile/data/auth/auth_repository_impl.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

class SaneamientoHomePage extends StatefulWidget {
  const SaneamientoHomePage({
    super.key,
    required this.api,
    required this.turno,
  });

  final ApiClient api;
  final String turno;

  @override
  State<SaneamientoHomePage> createState() => _SaneamientoHomePageState();
}

class _SaneamientoHomePageState extends State<SaneamientoHomePage> {
  bool _loading = true;
  String? _error;

  ReportPendiente? _pendiente;

  late final FetchSaneamientoPendientes _fetchSaneamientoPendientes;
  late final OpenSaneamientoReport _openSaneamientoReport;

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _fetchSaneamientoPendientes = FetchSaneamientoPendientes(repository);
    _openSaneamientoReport = OpenSaneamientoReport(repository);
    _loadPendientes();
  }

  Future<void> _loadPendientes() async {
    setState(() {
      _loading = true;
      _error = null;
      _pendiente = null;
    });

    try {
      final items = await _fetchSaneamientoPendientes.call(
        hours: 24,
        turno: widget.turno,
      );

      if (items.isNotEmpty) {
        _pendiente = items.first;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  DateTime _parseFecha(String? s) {
    if (s == null || s.trim().isEmpty) return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _openPendiente() async {
    final p = _pendiente;
    if (p == null) return;

    final fecha = _parseFecha(p.fecha);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaneamientoBackendPage(
          api: widget.api,
          reporteId: p.reportId,
          fecha: fecha,
          turno: p.turno.isEmpty ? widget.turno : p.turno,
          saneador: p.creadoPorNombre,
        ),
      ),
    );

    if (!mounted) return;
    _loadPendientes();
  }

  Future<void> _crearNuevoYEntrar() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final reporte = await _openSaneamientoReport.call(
        fecha: DateTime.now(),
        turno: widget.turno,
      );

      final fecha = _parseFecha(reporte.fecha);
      final turno = reporte.turno;
      final saneador = reporte.creadoPorNombre;

      if (!mounted) return;
      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SaneamientoBackendPage(
            api: widget.api,
            reporteId: reporte.id,
            fecha: fecha,
            turno: turno,
            saneador: saneador,
          ),
        ),
      );

      if (!mounted) return;
      _loadPendientes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = _pendiente;
    final tienePendiente = pendiente != null && pendiente.pendientes > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saneamiento'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPendientes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                elevation: 0,
                child: ListTile(
                  title: const Text('Error cargando información'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadPendientes,
                  ),
                ),
              ),

            if (!_loading && _error == null) ...[
              if (pendiente != null) ...[
                Text('Fecha: ${_formatDate(_parseFecha(pendiente.fecha))}'),
                Text(
                  'Turno: ${pendiente.turno.isEmpty ? widget.turno : pendiente.turno}',
                ),
                Text('Saneamiento: ${pendiente.creadoPorNombre}'),
              ] else ...[
                Text('Turno: ${widget.turno}'),
              ],

              const SizedBox(height: 12),
              const Divider(),

              // ✅ Banner amarillo
              if (tienePendiente) ...[
                _WarningBanner(
                  text:
                      'Tienes ${pendiente!.pendientes} saneamiento(s) pendiente(s). Completa la hora fin y/o labores para cerrar el reporte.',
                ),
                const SizedBox(height: 16),
              ],

              Text(
                'Reportes en espera (24h)',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              // ✅ Tarjeta pendiente
              if (tienePendiente)
                _PendienteCard(
                  pendientes: pendiente!.pendientes,
                  onTap: _openPendiente,
                )
              else
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No tienes saneamientos pendientes (24h)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Puedes iniciar un reporte nuevo. Si dejas líneas sin hora fin o sin labores, aparecerán aquí por 24 horas.',
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _crearNuevoYEntrar,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Iniciar reporte'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendienteItem {
  final int reportId;
  final String fecha;
  final String turno;
  final String creadoPorNombre;
  final int pendientes;

  const _PendienteItem({
    required this.reportId,
    required this.fecha,
    required this.turno,
    required this.creadoPorNombre,
    required this.pendientes,
  });

  factory _PendienteItem.fromJson(Map<String, dynamic> json) {
    return _PendienteItem(
      reportId: (json['report_id'] as num?)?.toInt() ?? 0,
      fecha: (json['fecha'] ?? '').toString(),
      turno: (json['turno'] ?? '').toString(),
      creadoPorNombre: (json['creado_por_nombre'] ?? '').toString(),
      pendientes: (json['pendiente'] as num?)?.toInt() ?? 0, // 👈 CLAVE
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendienteCard extends StatelessWidget {
  const _PendienteCard({required this.pendientes, required this.onTap});

  final int pendientes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Saneamientos pendientes (24h)',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(.25),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.amber.withOpacity(.6)),
                    ),
                    child: Text(
                      '$pendientes pendiente(s)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.groups_2_outlined, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$pendientes trabajador(es) con pendiente (hora fin o labores)',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Toca la tarjeta para completar lo pendiente.\n'
                'Si no se completa en 24 horas se elimina automáticamente.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
