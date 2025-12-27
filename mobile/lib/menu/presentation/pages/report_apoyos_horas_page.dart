import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';

class ApoyosHorasBackendPage extends StatefulWidget {
  const ApoyosHorasBackendPage({
    super.key,
    required this.api,
    required this.reporteId,
    required this.fecha,
    required this.turno,
    required this.planillero,
  });

  final ApiClient api;
  final int reporteId;
  final DateTime fecha;
  final String turno;
  final String planillero;

  @override
  State<ApoyosHorasBackendPage> createState() => _ApoyosHorasBackendPageState();
}

class _ApoyosHorasBackendPageState extends State<ApoyosHorasBackendPage> {
  bool _loading = true;
  String? _error;

  List<ApoyoHoraDto> _pendientes = [];
  List<ApoyoHoraDto> _completos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fechaStr(DateTime d) => d.toLocal().toString().split(' ').first;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await widget.api.get(
        '/reportes/${widget.reporteId}/apoyos-horas',
      );

      final body = jsonDecode(resp.body);

      if (resp.statusCode != 200) {
        final msg = (body is Map && body['error'] != null)
            ? body['error'].toString()
            : 'Error HTTP ${resp.statusCode}';
        throw Exception(msg);
      }

      final list = (body as List)
          .whereType<Map<String, dynamic>>()
          .map(ApoyoHoraDto.fromJson)
          .toList();

      final pendientes = <ApoyoHoraDto>[];
      final completos = <ApoyoHoraDto>[];

      for (final a in list) {
        if (a.horaFin == null || a.horaFin!.trim().isEmpty) {
          pendientes.add(a);
        } else {
          completos.add(a);
        }
      }

      if (!mounted) return;
      setState(() {
        _pendientes = pendientes;
        _completos = completos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete(ApoyoHoraDto a) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar apoyo'),
            content: const Text('¿Seguro que deseas eliminar este registro?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      // Si tu ApiClient no tiene delete(), añade método delete.
      // Por ahora asumimos que lo tienes, si no te lo doy.
      final resp = await widget.api.post(
        '/reportes/${widget.reporteId}/apoyos-horas/${a.id}/delete',
        {},
      );

      final data = jsonDecode(resp.body);
      if (resp.statusCode != 200) {
        throw Exception((data['error'] ?? 'Error eliminando').toString());
      }

      await _load();
    } catch (e) {
      _toast('No se pudo eliminar: $e');
    }
  }

  Future<void> _createOrUpdate({
    int? id,
    required String codigoTrabajador,
    String? nombreTrabajador,
    required String horaInicio,
    String? horaFin,
    required String areaApoyo,
  }) async {
    try {
      final path = (id == null)
          ? '/reportes/${widget.reporteId}/apoyos-horas'
          : '/reportes/${widget.reporteId}/apoyos-horas/$id';

      final resp = await widget.api.post(path, {
        'codigo_trabajador': codigoTrabajador,
        'nombre_trabajador': nombreTrabajador,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'area_apoyo': areaApoyo,
      });

      final data = jsonDecode(resp.body);
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception((data['error'] ?? 'Error guardando').toString());
      }

      await _load();
    } catch (e) {
      _toast('No se pudo guardar: $e');
    }
  }

  Future<void> _openNuevo() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApoyoHoraForm(
        title: 'Nuevo apoyo',
        onSave: (v) => _createOrUpdate(
          codigoTrabajador: v.codigo,
          nombreTrabajador: v.nombre,
          horaInicio: v.horaInicio,
          horaFin: v.horaFin,
          areaApoyo: v.areaApoyo,
        ),
      ),
    );
  }

  Future<void> _openEditar(ApoyoHoraDto a) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApoyoHoraForm(
        title: 'Editar apoyo',
        initial: _ApoyoFormValue(
          codigo: a.codigoTrabajador,
          nombre: a.nombreTrabajador,
          horaInicio: a.horaInicio,
          horaFin: a.horaFin,
          areaApoyo: a.areaApoyo,
        ),
        onSave: (v) => _createOrUpdate(
          id: a.id,
          codigoTrabajador: v.codigo,
          nombreTrabajador: v.nombre,
          horaInicio: v.horaInicio,
          horaFin: v.horaFin,
          areaApoyo: v.areaApoyo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = _fechaStr(widget.fecha);

    return Scaffold(
      appBar: AppBar(title: const Text('Apoyos por horas')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reporte #${widget.reporteId}'),
                Text('Fecha: $fechaStr'),
                Text('Turno: ${widget.turno}'),
                Text('Planillero: ${widget.planillero}'),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                ? Center(child: Text('Error: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        if (_pendientes.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                            child: Text(
                              'Pendientes (sin hora fin)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ..._pendientes.map(
                            (a) => ListTile(
                              title: Text(
                                '${a.codigoTrabajador} • ${a.areaApoyo}',
                              ),
                              subtitle: Text(
                                'Inicio ${a.horaInicio}  →  Fin ${a.horaFin ?? "--:--"}',
                              ),
                              onTap: () => _openEditar(a),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(a),
                              ),
                            ),
                          ),
                          const Divider(height: 0),
                        ],
                        if (_completos.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                            child: Text(
                              'Completados',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ..._completos.map(
                            (a) => ListTile(
                              title: Text(
                                '${a.codigoTrabajador} • ${a.areaApoyo}',
                              ),
                              subtitle: Text(
                                'De ${a.horaInicio} a ${a.horaFin}  →  ${a.horas.toStringAsFixed(2)} h',
                              ),
                              onTap: () => _openEditar(a),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(a),
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                        if (_pendientes.isEmpty && _completos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('Aún no hay apoyos registrados.'),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNuevo,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Agregar'),
      ),
    );
  }
}

/// =========================
/// DTO que viene del backend
/// =========================
class ApoyoHoraDto {
  final int id;
  final String codigoTrabajador;
  final String? nombreTrabajador;
  final String horaInicio;
  final String? horaFin;
  final double horas;
  final String areaApoyo;

  ApoyoHoraDto({
    required this.id,
    required this.codigoTrabajador,
    required this.nombreTrabajador,
    required this.horaInicio,
    required this.horaFin,
    required this.horas,
    required this.areaApoyo,
  });

  factory ApoyoHoraDto.fromJson(Map<String, dynamic> json) {
    return ApoyoHoraDto(
      id: (json['id'] as num).toInt(),
      codigoTrabajador: (json['trabajador_codigo'] ?? '').toString(),
      nombreTrabajador: json['trabajador_nombre']?.toString(),
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      horaFin: json['hora_fin']?.toString(),
      horas: (json['horas'] as num?)?.toDouble() ?? 0.0,
      areaApoyo: (json['area_apoyo'] ?? json['labores'] ?? '').toString(),
    );
  }
}

/// =========================
/// Form bottomsheet
/// =========================
class _ApoyoFormValue {
  final String codigo;
  final String? nombre;
  final String horaInicio;
  final String? horaFin;
  final String areaApoyo;

  _ApoyoFormValue({
    required this.codigo,
    required this.nombre,
    required this.horaInicio,
    required this.horaFin,
    required this.areaApoyo,
  });
}

class _ApoyoHoraForm extends StatefulWidget {
  const _ApoyoHoraForm({
    required this.title,
    this.initial,
    required this.onSave,
  });

  final String title;
  final _ApoyoFormValue? initial;
  final Future<void> Function(_ApoyoFormValue v) onSave;

  @override
  State<_ApoyoHoraForm> createState() => _ApoyoHoraFormState();
}

class _ApoyoHoraFormState extends State<_ApoyoHoraForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  late final TextEditingController _areaCtrl;

  @override
  void initState() {
    super.initState();
    _codigoCtrl = TextEditingController(text: widget.initial?.codigo ?? '');
    _nombreCtrl = TextEditingController(text: widget.initial?.nombre ?? '');
    _inicioCtrl = TextEditingController(text: widget.initial?.horaInicio ?? '');
    _finCtrl = TextEditingController(text: widget.initial?.horaFin ?? '');
    _areaCtrl = TextEditingController(text: widget.initial?.areaApoyo ?? '');
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 12,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código trabajador',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(
                labelText: 'Hora inicio (HH:mm)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _finCtrl,
              decoration: const InputDecoration(
                labelText: 'Hora fin (HH:mm) opcional',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: _areaCtrl,
              decoration: const InputDecoration(
                labelText: 'Área de apoyo',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  final v = _ApoyoFormValue(
                    codigo: _codigoCtrl.text.trim(),
                    nombre: _nombreCtrl.text.trim().isEmpty
                        ? null
                        : _nombreCtrl.text.trim(),
                    horaInicio: _inicioCtrl.text.trim(),
                    horaFin: _finCtrl.text.trim().isEmpty
                        ? null
                        : _finCtrl.text.trim(),
                    areaApoyo: _areaCtrl.text.trim(),
                  );

                  await widget.onSave(v);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
