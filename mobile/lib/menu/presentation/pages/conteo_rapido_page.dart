import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';

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
  DateTime _fecha = DateTime.now();
  String _turno = 'Dia';

  bool _loading = true;
  bool _saving = false;

  List<AreaConteo> _areas = [];
  List<AreaConteo> _areasFiltradas = [];

  String _search = '';
  int? _reporteIdAbierto; // para mostrar "Editando reporte #X"

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaInicial ?? DateTime.now();
    _turno = widget.turnoInicial ?? 'Dia';
    _cargarAreasYConteoGuardado();
  }

  // ----------------------------
  // Helpers UI
  // ----------------------------
  void _toast(String msg) {
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
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) {
      _areasFiltradas = List.of(_areas);
    } else {
      _areasFiltradas = _areas
          .where((a) => a.nombre.toLowerCase().contains(q))
          .toList(growable: false);
    }
  }

  void _inc(AreaConteo a) => setState(() => a.cantidad++);
  void _dec(AreaConteo a) => setState(() {
    if (a.cantidad > 0) a.cantidad--;
  });

  Widget _turnoButton(String v) {
    final sel = _turno == v;
    return Expanded(
      child: ElevatedButton(
        onPressed: _saving
            ? null
            : () async {
                setState(() => _turno = v);
                // al cambiar turno, recargar lo guardado para ese turno
                await _cargarAreasYConteoGuardado(recargarAreas: false);
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

  Future<void> _pickFecha() async {
    if (_saving) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
      // al cambiar fecha, recargar lo guardado para esa fecha/turno
      await _cargarAreasYConteoGuardado(recargarAreas: false);
    }
  }

  // ----------------------------
  // Data loading
  // ----------------------------
  Future<void> _cargarAreasYConteoGuardado({bool recargarAreas = true}) async {
    setState(() => _loading = true);

    try {
      // 1) Cargar catálogo de áreas (solo si se pide)
      if (recargarAreas || _areas.isEmpty) {
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
      }

      // 2) Abrir/revisar reporte guardado para fecha/turno (trae items)
      final fechaStr = _fmtFecha(_fecha);
      final respOpen = await widget.api.get(
        '/reportes/conteo-rapido/open?fecha=$fechaStr&turno=${Uri.encodeQueryComponent(_turno)}',
      );

      if (respOpen.statusCode != 200 && respOpen.statusCode != 201) {
        throw Exception('Open error ${respOpen.statusCode}: ${respOpen.body}');
      }

      final dataOpen = jsonDecode(respOpen.body) as Map<String, dynamic>;
      final reporte = dataOpen['reporte'] as Map<String, dynamic>;
      _reporteIdAbierto = (reporte['id'] as num).toInt();

      final items =
          (dataOpen['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // 3) Aplicar cantidades guardadas a las áreas
      final mapCant = <int, int>{};
      for (final it in items) {
        final aid = (it['area_id'] as num).toInt();
        final cant = (it['cantidad'] as num).toInt();
        mapCant[aid] = cant;
      }

      for (final a in _areas) {
        a.cantidad = mapCant[a.id] ?? 0;
      }

      // 4) Filtrar
      _aplicarFiltro();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      _toast('No se pudo cargar: $e');
    }
  }

  // ----------------------------
  // Save flow with summary dialog
  // ----------------------------
  Future<void> _guardar() async {
    if (_saving) return;

    final items = _areas
        .where((a) => a.cantidad > 0)
        .map((a) => {'area_id': a.id, 'cantidad': a.cantidad})
        .toList();

    if (items.isEmpty) {
      _toast('Ingresa al menos un conteo (> 0).');
      return;
    }

    final resumen = _resumenItems();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar conteo'),
        content: SingleChildScrollView(child: Text(resumen)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
      _toast('Guardado. Reporte #$reporteId');

      // recarga para asegurarnos que quedó tal cual en BD (y mantener id)
      await _cargarAreasYConteoGuardado(recargarAreas: false);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------------------------
  // Build
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerScope.of(context);
    final planillero = auth.user?.nombre ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conteo Rápido'),
        backgroundColor: const Color(0xFF00796B),
        actions: [
          IconButton(
            onPressed: (_saving || _loading)
                ? null
                : () => _cargarAreasYConteoGuardado(recargarAreas: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_reporteIdAbierto != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Editando reporte #$_reporteIdAbierto',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        TextFormField(
                          initialValue: planillero,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Planillero',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _saving ? null : _pickFecha,
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
                        const SizedBox(height: 12),

                        // Buscador
                        TextField(
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Buscar área',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _search = v;
                              _aplicarFiltro();
                            });
                          },
                        ),
                        const SizedBox(height: 16),

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
                            child: Text('No hay áreas con ese filtro.'),
                          ),
                      ],
                    ),
                  ),

                  // Footer fijo sin overflow
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
                              child: Text(_saving ? 'Guardando...' : 'Guardar'),
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
