import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/core/ui/notifications.dart';

class AreaConteo {
  final int id;
  final String nombre;
  int cantidad;

  AreaConteo({required this.id, required this.nombre, this.cantidad = 0});

  factory AreaConteo.fromJson(Map<String, dynamic> j) => AreaConteo(
    id: (j['id'] as num).toInt(),
    nombre: (j['nombre'] ?? '').toString(),
    cantidad: 0,
  );
}

class ConteoRapidoPage extends StatefulWidget {
  const ConteoRapidoPage({
    super.key,
    required this.api,
    this.fechaInicial,
    this.turnoInicial,
  });

  final ApiClient api;
  final DateTime? fechaInicial;
  final String? turnoInicial;

  @override
  State<ConteoRapidoPage> createState() => _ConteoRapidoPageState();
}

class _ConteoRapidoPageState extends State<ConteoRapidoPage> {
  // ✅ Selección (clave del reporte)
  DateTime _fecha = DateTime.now();
  String _turno = 'Dia';

  // ✅ Estado flujo iniciar
  bool _checkingOpen = false;
  String? _openError;

  bool _tieneReporte = false;
  bool _existente = false;
  bool _mostrarListado = false;

  int? _reporteId;
  List<Map<String, dynamic>> _itemsOpen = [];

  // ✅ Estado de data
  bool _loadingAreas = true; // solo carga catálogo
  bool _saving = false;

  List<AreaConteo> _areas = [];
  List<AreaConteo> _areasFiltradas = [];

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaInicial ?? DateTime.now();
    _turno = widget.turnoInicial ?? 'Dia';
    _cargarCatalogoAreas(); // ✅ solo catálogo, no abre reporte automáticamente
  }

  // ----------------------------
  // Helpers UI
  // ----------------------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtFecha(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _resumenItems() {
    final selected = _areas.where((a) => a.cantidad > 0).toList();
    if (selected.isEmpty) return 'No hay cantidades ingresadas.';
    selected.sort((a, b) => a.nombre.compareTo(b.nombre));
    return selected.map((a) => '${a.nombre}: ${a.cantidad}').join('\n');
  }

  void _aplicarFiltro() {
    // ✅ Quitaste buscador => siempre todos
    _areasFiltradas = List.of(_areas);
  }

  void _inc(AreaConteo a) => setState(() => a.cantidad++);
  void _dec(AreaConteo a) => setState(() {
    if (a.cantidad > 0) a.cantidad--;
  });

  Widget _turnoButton(String v) {
    final sel = _turno == v;
    return Expanded(
      child: ElevatedButton(
        onPressed: (_saving || _checkingOpen)
            ? null
            : () async {
                setState(() => _turno = v);

                // ✅ al cambiar clave (turno/fecha) reinicia flujo
                _resetFlujo();

                // no toca catálogo, pero deja lista en 0 (hasta iniciar)
                _resetCantidades();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: sel ? const Color(0xFF00796B) : Colors.grey[300],
          foregroundColor: sel ? Colors.white : Colors.black,
          elevation: sel ? 1 : 0,
        ),
        child: Text(v.toUpperCase()),
      ),
    );
  }

  void _resetFlujo() {
    setState(() {
      _openError = null;
      _tieneReporte = false;
      _existente = false;
      _mostrarListado = false;
      _reporteId = null;
      _itemsOpen = [];
    });
  }

  void _resetCantidades() {
    for (final a in _areas) {
      a.cantidad = 0;
    }
    _aplicarFiltro();
    if (mounted) setState(() {});
  }

  Future<void> _pickFecha() async {
    if (_saving || _checkingOpen) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _fecha = picked);

      // ✅ al cambiar clave (turno/fecha) reinicia flujo
      _resetFlujo();

      // deja cantidades en 0 hasta iniciar
      _resetCantidades();
    }
  }

  // ----------------------------
  // Data loading (solo catálogo)
  // ----------------------------
  Future<void> _cargarCatalogoAreas() async {
    setState(() => _loadingAreas = true);

    try {
      final respAreas = await widget.api.get('/areas/conteo-rapido');
      if (respAreas.statusCode != 200) {
        throw Exception(
          'Áreas error ${respAreas.statusCode}: ${respAreas.body}',
        );
      }
      final dataAreas = jsonDecode(respAreas.body) as Map<String, dynamic>;
      final listAreas = (dataAreas['areas'] as List)
          .cast<Map<String, dynamic>>();

      _areas = listAreas.map(AreaConteo.fromJson).toList();
      _aplicarFiltro();

      setState(() => _loadingAreas = false);
    } catch (e) {
      setState(() => _loadingAreas = false);
      _toast('No se pudo cargar áreas: $e');
    }
  }

  // ----------------------------
  // OPEN / INICIAR
  // ----------------------------
  Future<void> _iniciarReporte() async {
    if (_checkingOpen || _saving) return;

    setState(() {
      _checkingOpen = true;
      _openError = null;
      _tieneReporte = false;
      _existente = false;
      _mostrarListado = false;
      _reporteId = null;
      _itemsOpen = [];
    });

    try {
      final fechaStr = _fmtFecha(_fecha);

      final resp = await widget.api.get(
        "/reportes/conteo-rapido/open?turno=${Uri.encodeQueryComponent(_turno)}&fecha=$fechaStr",
      );

      final decoded = jsonDecode(resp.body);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final msg = (decoded is Map && decoded["error"] != null)
            ? decoded["error"].toString()
            : "Error HTTP ${resp.statusCode}";
        throw Exception(msg);
      }

      final existente = decoded["existente"] == true;
      final rep = (decoded["reporte"] as Map).cast<String, dynamic>();
      final id = (rep["id"] as num).toInt();

      final items = (decoded["items"] is List)
          ? (decoded["items"] as List)
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _tieneReporte = true;
        _existente = existente;
        _reporteId = id;
        _itemsOpen = items;

        // ✅ si NO existe, ya se empieza a llenar
        if (!existente) {
          _mostrarListado = true;
        }
      });

      // Si existe: mostramos tarjeta "ya existe" y el usuario decide "Continuar"
    } catch (e) {
      setState(() => _openError = e.toString());
    } finally {
      if (mounted) setState(() => _checkingOpen = false);
    }
  }

  void _continuarReporteExistente() {
    // ✅ aplicar cantidades devueltas por open/items
    final mapCant = <int, int>{};
    for (final it in _itemsOpen) {
      final aid = (it['area_id'] as num).toInt();
      final cantAny = it['cantidad'];
      final cant = (cantAny is num)
          ? cantAny.toInt()
          : int.tryParse('$cantAny') ?? 0;
      mapCant[aid] = cant;
    }

    for (final a in _areas) {
      a.cantidad = mapCant[a.id] ?? 0;
    }

    _aplicarFiltro();

    setState(() {
      _mostrarListado = true;
    });
  }

  // ----------------------------
  // Save flow with summary dialog
  // ----------------------------
  Future<void> _guardar() async {
    if (_saving) return;

    // ✅ No guardar si no inició
    if (!_mostrarListado || _reporteId == null) {
      _toast('Primero inicia el reporte.');
      return;
    }

    final items = _areas
        .where((a) => a.cantidad > 0)
        .map((a) => {'area_id': a.id, 'cantidad': a.cantidad})
        .toList();

    if (items.isEmpty) {
      _toast('Ingresa al menos un conteo (> 0).');
      return;
    }

    final resumen = _resumenItems();
    final parentContext = context;

    final confirmar = await showDialog<bool>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar conteo'),
        content: SingleChildScrollView(child: Text(resumen)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar y guardar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _saving = true);

    try {
      final payload = {
        'fecha': _fmtFecha(_fecha),
        'turno': _turno,
        'items': items,
      };

      final resp = await widget.api.post('/reportes/conteo-rapido', payload);

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception('Error ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final reporteId = data['reporte_id'];

      if (!mounted) return;

      // ✅ Mostrar notificación bonita
      showSavedToast(context, message: 'Guardado. Reporte #$reporteId');

      // ✅ dar un mini tiempo para que se vea el toast antes de salir
      await Future.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;

      // ✅ SALIR de ConteoRapidoPage (así ya no se queda la lista)
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------------------------
  // UI Blocks
  // ----------------------------
  Widget _bloqueInicioUI() {
    if (_openError != null) {
      return Card(
        child: ListTile(
          title: const Text("Error"),
          subtitle: Text(_openError!),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkingOpen ? null : _iniciarReporte,
          ),
        ),
      );
    }

    // Antes de iniciar
    if (!_tieneReporte) {
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (_checkingOpen || _saving) ? null : _iniciarReporte,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
          ),
          icon: _checkingOpen
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: const Text("INICIAR REPORTE"),
        ),
      );
    }

    // Existe reporte para esa fecha+turno y aún no decidieron continuar
    if (_existente && _reporteId != null && !_mostrarListado) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ya existe un reporte para esta fecha y turno",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                "Reporte #${_reporteId!}",
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _continuarReporteExistente,
                      child: const Text("Continuar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // ✅ Cambia esta ruta por la tuya real
                        Navigator.pushNamed(context, "/reports/list");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Ver reportes"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ----------------------------
  // Build
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerScope.of(context);
    final planillero = auth.user?.nombre ?? ''; // ya no se muestra
    // ignore: unused_local_variable
    final _ = planillero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conteo Rápido'),
        backgroundColor: const Color(0xFF00796B),
        actions: [
          IconButton(
            onPressed: (_saving || _checkingOpen)
                ? null
                : () async {
                    await _cargarCatalogoAreas();
                    _resetFlujo();
                    _resetCantidades();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingAreas
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ✅ Fecha + Turno (la clave)
                        InkWell(
                          onTap: (_saving || _checkingOpen) ? null : _pickFecha,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_fmtFecha(_fecha)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _turnoButton('Dia'),
                            const SizedBox(width: 10),
                            _turnoButton('Noche'),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ✅ Botón iniciar / ya existe
                        _bloqueInicioUI(),

                        const SizedBox(height: 14),

                        // ✅ Listado SOLO después de iniciar (o continuar)
                        if (_mostrarListado) ...[
                          const Text(
                            'Áreas (cantidad)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          ..._areasFiltradas.map(
                            (a) => Card(
                              child: ListTile(
                                title: Text(a.nombre),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _saving ? null : () => _dec(a),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${a.cantidad}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _saving ? null : () => _inc(a),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (_areasFiltradas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: Text('No hay áreas disponibles.'),
                            ),
                        ],
                      ],
                    ),
                  ),

                  // ✅ Footer solo cuando ya puedes guardar
                  if (_mostrarListado)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Volver'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saving ? null : _guardar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                ),
                                child: Text(
                                  _saving ? 'Guardando...' : 'Guardar',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
