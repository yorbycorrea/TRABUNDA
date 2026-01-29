//import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/menu/presentation/pages/saneamiento_backend_page.dart';
import 'package:mobile/features/state_saneamiento.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';
import 'package:mobile/domain/reports/models/report_models.dart';

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
  ReportOpenInfo? _saneaInfo;
  DateTime _fecha = DateTime.now();
  String _turno = 'Dia';
  bool _creando = false;
  int _openRequestId = 0;
  String? _openQueryKey;

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
    _openOrGetSaneamiento();
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

  void _resetSaneamientoState() {
    _loadingSanea = false;
    _errorSanea = null;
    _saneaInfo = null;
    _creando = false;
  }

  String _buildQueryKey() {
    final fechaKey = _fecha.toLocal().toString().split(' ').first;
    return '$fechaKey|$_turno';
  }

  bool _isLatestRequest(int requestId, String queryKey) {
    return requestId == _openRequestId && queryKey == _openQueryKey;
  }

  Future<void> _openOrGetSaneamiento() async {
    final requestId = ++_openRequestId;
    final queryKey = _buildQueryKey();
    _openQueryKey = queryKey;
    setState(() {
      _loadingSanea = true;
      _errorSanea = null;
      _saneaInfo = null;
    });

    try {
      debugPrint('[TEMP] Abriendo saneamiento: fecha=$_fecha, turno=$_turno');
      final reporte = await _openSaneamientoReport.call(
        fecha: _fecha,
        turno: _turno,
      );
      if (!_isLatestRequest(requestId, queryKey)) {
        debugPrint(
          '[TEMP] Ignorando respuesta saneamiento desfasada '
          '(requestId=$requestId, queryKey=$queryKey)',
        );
        return;
      }
      debugPrint(
        '[TEMP] Respuesta saneamiento: existente=${reporte.id != 0}, '
        'estado=${reporte.estado}, id=${reporte.id}',
      );

      setState(() => _saneaInfo = reporte);
    } catch (e) {
      debugPrint('Saneamiento error -> $e');
      if (_isLatestRequest(requestId, queryKey)) {
        setState(() => _errorSanea = e.toString());
      }
    } finally {
      if (_isLatestRequest(requestId, queryKey)) {
        setState(() => _loadingSanea = false);
      }
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

      _resetSaneamientoState();
    });
    if (!mounted) return;

    await _openOrGetSaneamiento();
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

      final reporte = _saneaInfo;
      if (reporte == null) {
        _toast('No se pudo obtener el reporte de saneamiento');
        return;
      }

      // 2) abre la pantalla de detalle con el id abierto
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SaneamientoBackendPage(
            api: widget.api,
            reporteId: reporte.id,
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

    final saneaInfo = _saneaInfo;
    final saneaExiste = saneaInfo != null;
    final estado = saneaInfo?.estado ?? '';
    final allowCreate = saneaInfo?.allowCreate ?? false;
    final reporteId = saneaInfo?.id;
    final actionLabel = estado == 'CERRADO'
        ? 'Ver reporte'
        : estado == 'ABIERTO'
        ? 'Continuar'
        : allowCreate
        ? 'Crear reporte'
        : null;

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
                                    _resetSaneamientoState();
                                  });
                                  if (!mounted) return;
                                  _openOrGetSaneamiento();
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
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
                                  : estado == 'CERRADO'
                                  ? 'Reporte completado • Reporte ID: $reporteId'
                                  : estado == 'ABIERTO'
                                  ? 'Continuar • Reporte ID: $reporteId'
                                  : saneaExiste
                                  ? 'Crear y registrar saneamiento'
                                  : 'Crear y registrar saneamiento',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (actionLabel != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_creando || _loadingSanea)
                            ? null
                            : () async {
                                if (actionLabel == 'Ver reporte' ||
                                    actionLabel == 'Continuar') {
                                  await _abrirSaneamiento();
                                  return;
                                }

                                if (actionLabel == 'Crear reporte') {
                                  final id = await _crearReporteSaneamiento();
                                  if (!mounted) return;
                                  setState(
                                    () => _saneaInfo = ReportOpenInfo(
                                      id: id,
                                      fecha: _fecha
                                          .toLocal()
                                          .toString()
                                          .split(' ')
                                          .first,
                                      turno: _turno,
                                      creadoPorNombre: _usuarioCtrl.text.trim(),
                                      allowCreate: true,
                                      estado: 'ABIERTO',
                                    ),
                                  );
                                  await _abrirSaneamiento();
                                }
                              },
                        child: Text(actionLabel),
                      ),
                    ),
                  if (actionLabel == null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: null,
                        child: const Text('No disponible'),
                      ),
                    ),
                  if (_creando || _loadingSanea)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
