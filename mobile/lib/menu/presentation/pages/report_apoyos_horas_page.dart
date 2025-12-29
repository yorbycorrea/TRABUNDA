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
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool _loadingAreas = true;
  String? _errorAreas;
  List<_AreaItem> _areas = [];

  final List<_ApoyoFormModel> _trabajadores = [_ApoyoFormModel()];

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loadingAreas = true;
      _errorAreas = null;
      _areas = [];
    });

    try {
      final resp = await widget.api.get('/areas?tipo=APOYO_HORAS');
      debugPrint('STATUS: ${resp.statusCode}');
      debugPrint('BODY: ${resp.body}');

      // ✅ Si el backend devuelve HTML, esto evita crashear con FormatException
      final body = resp.body.trimLeft();
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
        throw Exception(
          'El backend devolvió HTML (no JSON). Revisa la URL/baseUrl o que exista GET /areas?tipo=APOYO_HORAS.\n'
          'HTTP ${resp.statusCode}',
        );
      }

      final decoded = jsonDecode(resp.body);

      if (resp.statusCode != 200) {
        final msg = (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'Error cargando áreas (HTTP ${resp.statusCode})';
        throw Exception(msg);
      }

      if (decoded is! List) {
        throw Exception('Respuesta inválida: se esperaba una lista JSON.');
      }

      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => _AreaItem(
              id: (e['id'] as num).toInt(),
              nombre: (e['nombre'] ?? '').toString(),
              activo: (e['activo'] as num?)?.toInt() ?? 1,
            ),
          )
          .where((a) => a.activo == 1)
          .toList();

      if (!mounted) return;
      setState(() {
        _areas = list;
        _loadingAreas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAreas = false;
        _errorAreas = e.toString();
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double _calcHoras(TimeOfDay inicio, TimeOfDay fin) {
    final start = Duration(hours: inicio.hour, minutes: inicio.minute);
    final end = Duration(hours: fin.hour, minutes: fin.minute);
    final diff = end - start;
    return diff.inMinutes / 60.0;
  }

  Future<void> _pickHora(_ApoyoFormModel m, bool inicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (inicio ? m.inicio : m.fin) ?? const TimeOfDay(hour: 6, minute: 0),
    );
    if (picked == null) return;

    setState(() {
      if (inicio) {
        m.inicio = picked;
      } else {
        m.fin = picked;
      }
      if (m.inicio != null && m.fin != null) {
        m.horas = _calcHoras(m.inicio!, m.fin!);
      }
    });
  }

  void _addTrabajador() => setState(() => _trabajadores.add(_ApoyoFormModel()));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación mínima
    for (final t in _trabajadores) {
      if (t.inicio == null || t.areaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa hora inicio y área para todos.'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      for (final t in _trabajadores) {
        final horaInicio = _formatTime(t.inicio!);
        final horaFin = t.fin != null ? _formatTime(t.fin!) : null;
        final horas = (t.fin != null) ? _calcHoras(t.inicio!, t.fin!) : 0.0;

        // 👉 OJO: este endpoint debes tenerlo en backend
        final resp = await widget.api.post(
          '/reportes/${widget.reporteId}/apoyos-horas',
          {
            'trabajador_codigo': t.codigoCtrl.text.trim(),
            'trabajador_nombre': t.nombreCtrl.text.trim(),
            'hora_inicio': horaInicio,
            'hora_fin': horaFin,
            'horas': horas,
            'area_id': t.areaId, // ✅ viene del backend
            'area': t.areaNombre, // ✅ opcional, pero útil
          },
        );

        final body = resp.body.trimLeft();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          throw Exception(
            'El backend devolvió HTML en guardar. HTTP ${resp.statusCode}',
          );
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = _formatDate(widget.fecha);

    return Scaffold(
      appBar: AppBar(title: const Text('Apoyos por horas')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Reporte #${widget.reporteId}'),
              Text('Fecha: $fechaStr'),
              Text('Turno: ${widget.turno}'),
              Text('Planillero: ${widget.planillero}'),
              const SizedBox(height: 10),
              const Divider(),

              // ✅ Estado de áreas
              if (_loadingAreas)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorAreas != null)
                Card(
                  elevation: 0,
                  child: ListTile(
                    title: const Text('No se pudieron cargar las áreas'),
                    subtitle: Text(_errorAreas!),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadAreas,
                    ),
                  ),
                )
              else if (_areas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay áreas disponibles para APOYO_HORAS.'),
                ),

              // ✅ Formulario SOLO si ya hay áreas
              if (!_loadingAreas &&
                  _errorAreas == null &&
                  _areas.isNotEmpty) ...[
                for (int i = 0; i < _trabajadores.length; i++)
                  _TrabajadorCard(
                    index: i,
                    model: _trabajadores[i],
                    areas: _areas,
                    onPickInicio: () => _pickHora(_trabajadores[i], true),
                    onPickFin: () => _pickHora(_trabajadores[i], false),
                    onChangedArea: (a) {
                      _trabajadores[i].areaId = a.id;
                      _trabajadores[i].areaNombre = a.nombre;
                    },
                  ),

                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _addTrabajador,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Agregar trabajador'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar y volver'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ApoyoFormModel {
  final codigoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();

  TimeOfDay? inicio;
  TimeOfDay? fin;
  double horas = 0.0;

  int? areaId;
  String? areaNombre;
}

class _AreaItem {
  final int id;
  final String nombre;
  final int activo;

  const _AreaItem({
    required this.id,
    required this.nombre,
    required this.activo,
  });
}

class _TrabajadorCard extends StatelessWidget {
  const _TrabajadorCard({
    required this.index,
    required this.model,
    required this.areas,
    required this.onPickInicio,
    required this.onPickFin,
    required this.onChangedArea,
  });

  final int index;
  final _ApoyoFormModel model;
  final List<_AreaItem> areas;
  final VoidCallback onPickInicio;
  final VoidCallback onPickFin;
  final void Function(_AreaItem) onChangedArea;

  String _horaText(TimeOfDay? t) {
    if (t == null) return '--:--';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceVariant.withOpacity(.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trabajador ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _HoraBox(
                    label: 'Hora inicio',
                    value: _horaText(model.inicio),
                    onTap: onPickInicio,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HoraBox(
                    label: 'Hora fin (opcional)',
                    value: _horaText(model.fin),
                    onTap: onPickFin,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: model.codigoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código del trabajador',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.qr_code_scanner),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el código' : null,
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: model.nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del trabajador',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<int>(
              value: model.areaId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Área de apoyo',
                border: OutlineInputBorder(),
              ),
              items: areas
                  .map(
                    (a) => DropdownMenuItem<int>(
                      value: a.id,
                      child: Text(a.nombre, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                final selected = areas.firstWhere((a) => a.id == id);
                model.areaId = selected.id;
                model.areaNombre = selected.nombre;
                onChangedArea(selected);
              },
              validator: (v) =>
                  v == null ? 'Selecciona el área de apoyo' : null,
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total horas: ${model.fin == null ? '--' : model.horas.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoraBox extends StatelessWidget {
  const _HoraBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.access_time, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
