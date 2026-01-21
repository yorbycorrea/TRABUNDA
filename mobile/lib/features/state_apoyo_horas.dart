//import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/menu/presentation/pages/report_apoyos_horas_page.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

class ApoyosHorasHomePage extends StatefulWidget {
  const ApoyosHorasHomePage({
    super.key,
    required this.api,
    required this.turno,
  });

  final ApiClient api;
  final String turno;

  @override
  State<ApoyosHorasHomePage> createState() => _ApoyosHorasHomePageState();
}

class _ApoyosHorasHomePageState extends State<ApoyosHorasHomePage> {
  bool _loading = true;
  String? _error;

  ReportPendiente? _pendiente;

  // ✅ Estado local para el header seleccionable
  late DateTime _fechaSel;
  late String _turnoSel;

  static const Color kBluePrimary = Color(0xFF0A7CFF);
  static const Color kBlueSecondary = Color(0xFF4FC3F7);
  static const Color kBg = Color(0xFFF5F7FA);

  late final FetchApoyoHorasPendientes _fetchApoyoHorasPendientes;
  late final OpenApoyoHorasReport _openApoyoHorasReport;

  @override
  void initState() {
    super.initState();
    _fechaSel = DateTime.now();
    _turnoSel = widget.turno;
    final repository = ReportRepositoryImpl(widget.api);
    _fetchApoyoHorasPendientes = FetchApoyoHorasPendientes(repository);
    _openApoyoHorasReport = OpenApoyoHorasReport(repository);
    _loadPendientes();
  }

  Future<void> _loadPendientes() async {
    setState(() {
      _loading = true;
      _error = null;
      _pendiente = null;
    });

    try {
      // ✅ Formato YYYY-MM-DD para el backend
      final items = await _fetchApoyoHorasPendientes.call(
        hours: 24,
        fecha: _fechaSel,
        turno: _turnoSel,
      );

      if (items.isNotEmpty) {
        _pendiente = items.first;

        // ✅ Si vino un pendiente con fecha/turno, reflejarlo en el header (solo UI)
        final p = _pendiente!;
        final f2 = _parseFecha(p.fecha);
        final t2 = p.turno.isNotEmpty ? p.turno : _turnoSel;

        _fechaSel = f2;
        _turnoSel = t2;
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

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSel,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() => _fechaSel = picked);

    // ✅ Solo recargar (misma lógica). Si luego quieres filtrar por fecha,
    // ahí sí habría que cambiar el endpoint.
    _loadPendientes();
  }

  void _setTurno(String v) {
    setState(() => _turnoSel = v);
    _loadPendientes();
  }

  Future<void> _openPendiente() async {
    final p = _pendiente;
    if (p == null) return;

    final fecha = _parseFecha(p.fecha);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApoyosHorasBackendPage(
          api: widget.api,
          reporteId: p.reportId,
          fecha: fecha,
          turno: p.turno.isEmpty ? _turnoSel : p.turno,
          planillero: p.creadoPorNombre,
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

      final reporte = await _openApoyoHorasReport.call(
        fecha: _fechaSel,
        turno: _turnoSel,
      );

      final fecha = _parseFecha(reporte.fecha);
      final turno = reporte.turno;
      final planillero = reporte.creadoPorNombre;

      if (!mounted) return;

      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApoyosHorasBackendPage(
            api: widget.api,
            reporteId: reporte.id,
            fecha: fecha,
            turno: turno,
            planillero: planillero,
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
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Apoyos por horas'),
        elevation: 0,
        backgroundColor: kBluePrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPendientes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ✅ Header seleccionable (Fecha + Turno)
            _HeaderFechaTurno(
              fechaText: _formatDate(_fechaSel),
              turnoValue: _turnoSel,
              onPickFecha: _pickFecha,
              onChangedTurno: _setTurno,
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        'Planillero: ${pendiente.creadoPorNombre}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Divider(),

                    if (tienePendiente) ...[
                      _WarningBanner(
                        text:
                            'Tienes ${pendiente!.pendientes} apoyo(s) pendiente(s). Completa la hora fin para cerrar el reporte.',
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Reportes en espera (24h)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (tienePendiente)
                      _PendienteCard(
                        pendientes: pendiente!.pendientes,
                        tarea: pendiente.areaNombre.isEmpty
                            ? 'Área pendiente'
                            : pendiente.areaNombre,
                        onTap: _openPendiente,
                      )
                    else
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No tienes apoyos pendientes (24h)',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Puedes iniciar un reporte nuevo. Si dejas líneas sin hora fin, aparecerán aquí por 24 horas.',
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 48,
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : _crearNuevoYEntrar,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kBluePrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
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
          ],
        ),
      ),
    );
  }
}

class _HeaderFechaTurno extends StatelessWidget {
  const _HeaderFechaTurno({
    required this.fechaText,
    required this.turnoValue,
    required this.onPickFecha,
    required this.onChangedTurno,
  });

  final String fechaText;
  final String turnoValue;
  final VoidCallback onPickFecha;
  final ValueChanged<String> onChangedTurno;

  static const Color kBluePrimary = Color(0xFF0A7CFF);
  static const Color kBlueSecondary = Color(0xFF4FC3F7);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kBluePrimary, kBlueSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FechaBox(
              label: 'Fecha',
              value: fechaText,
              onTap: onPickFecha,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TurnoBox(
              label: 'Turno',
              value: turnoValue,
              onChanged: onChangedTurno,
            ),
          ),
        ],
      ),
    );
  }
}

class _FechaBox extends StatelessWidget {
  const _FechaBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month_rounded, color: Colors.black54),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnoBox extends StatelessWidget {
  const _TurnoBox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: const ['Dia', 'Noche']
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
              },
            ),
          ),
        ],
      ),
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
  const _PendienteCard({
    required this.pendientes,
    required this.tarea,
    required this.onTap,
  });

  final int pendientes;
  final String tarea;
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
                      'Apoyos pendientes (24h)',
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
                      '$pendientes apoyo(s)',
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
                      '$pendientes trabajador(es) con hora fin pendiente',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.work_outline, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tarea.isEmpty ? 'Área' : tarea,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Toca la tarjeta para completar las horas fin de todos los apoyos.\n'
                'Si no se completan en 24 horas se eliminan automáticamente.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
