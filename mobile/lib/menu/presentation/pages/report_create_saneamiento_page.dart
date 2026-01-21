//import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/menu/presentation/pages/saneamiento_backend_page.dart';
import 'package:mobile/features/state_saneamiento.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

// import 'package:mobile/menu/presentation/pages/saneamiento_form_page.dart';

class ReportCreateSaneamientoPage extends StatefulWidget {
  const ReportCreateSaneamientoPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ReportCreateSaneamientoPage> createState() =>
      _ReportCreateSaneamientoPageState();
}

class _ReportCreateSaneamientoPageState
    extends State<ReportCreateSaneamientoPage> {
  bool _loadingSanea = false;
  String? _errorSanea;
  int? _saneaReporteId;
  DateTime _fecha = DateTime.now();
  String _turno = 'Dia';
  bool _creando = false;

  final TextEditingController _fechaCtrl = TextEditingController();
  final TextEditingController _usuarioCtrl = TextEditingController();

  late final OpenSaneamientoReport _openSaneamientoReport;
  late final CreateSaneamientoReport _createSaneamientoReport;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = AuthControllerScope.read(context);
    final user = auth.user;

    // ✅ aquí muestras nombre si ya lo tienes (si no, usa username)
    _usuarioCtrl.text = (user?.nombre ?? user?.username ?? '').trim();

    _fechaCtrl.text = _fecha.toLocal().toString().split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _openSaneamientoReport = OpenSaneamientoReport(repository);
    _createSaneamientoReport = CreateSaneamientoReport(repository);
  }

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _usuarioCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openOrGetSaneamiento() async {
    setState(() {
      _loadingSanea = true;
      _errorSanea = null;
      _saneaReporteId = null;
      _errorSanea = null;
    });

    try {
      final reporte = await _openSaneamientoReport.call(
        fecha: _fecha,
        turno: _turno,
      );

      setState(() => _saneaReporteId = reporte.id);
    } catch (e) {
      setState(() => _errorSanea = e.toString());
    } finally {
      setState(() => _loadingSanea = false);
    }
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: _fecha,
    );
    if (picked == null) return;
    setState(() {
      _fecha = picked;
      _fechaCtrl.text = _fecha.toLocal().toString().split(' ').first;
    });
  }

  Future<int> _crearReporteSaneamiento() async {
    final auth = AuthControllerScope.read(context);
    if (!auth.isAuthenticated) throw Exception('No autenticado');

    setState(() => _creando = true);
    try {
      return await _createSaneamientoReport.call(fecha: _fecha, turno: _turno);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _abrirSaneamiento() async {
    try {
      // 1) obtiene/crea el reporte abierto (igual que apoyo horas)
      await _openOrGetSaneamiento();
      if (!mounted) return;

      if (_saneaReporteId == null) {
        _toast('No se pudo obtener el reporte de saneamiento');
        return;
      }

      // 2) abre la pantalla de detalle con el id abierto
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SaneamientoBackendPage(
            api: widget.api,
            reporteId: _saneaReporteId!,
            fecha: _fecha,
            turno: _turno,
            saneador: _usuarioCtrl.text.trim(),
          ),
        ),
      );

      // 3) al volver, refresca el estado (para que siga diciendo EN ESPERA)
      if (!mounted) return;
      await _openOrGetSaneamiento();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final saneaExiste = _saneaReporteId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear reporte (Saneamiento)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: cs.surfaceVariant.withOpacity(.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          controller: _fechaCtrl,
                          onTap: _pickFecha,
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _turno,
                          items: const [
                            DropdownMenuItem(value: 'Dia', child: Text('Dia')),
                            DropdownMenuItem(
                              value: 'Noche',
                              child: Text('Noche'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Turno',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _creando
                              ? null
                              : (v) {
                                  setState(() {
                                    _turno = v ?? 'Dia';
                                    _saneaReporteId = null;
                                    _errorSanea = null;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usuarioCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Saneamiento (usuario)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ ÚNICA opción para este rol
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: (_creando || _loadingSanea)
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaneamientoHomePage(
                            api: widget.api,
                            turno: _turno,
                          ),
                        ),
                      );

                      // al volver, refresca el estado "EN ESPERA"
                      if (!mounted) return;
                      await _openOrGetSaneamiento();
                    },

              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(.10),
                      child: Icon(
                        Icons.cleaning_services_outlined,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saneamiento',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _loadingSanea
                                ? 'Verificando...'
                                : _errorSanea != null
                                ? 'Error: $_errorSanea'
                                : saneaExiste
                                ? 'EN ESPERA • Reporte ID: $_saneaReporteId'
                                : 'Crear y registrar saneamiento',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    (_creando || _loadingSanea)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
