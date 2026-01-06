import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/widgets/qr_scanner.dart';

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
    _loadLineasExistentes();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loadingAreas = true;
      _errorAreas = null;
      _areas = [];
    });

    try {
      final resp = await widget.api.get('/areas?tipo=APOYO_HORAS');

      final body = resp.body.trimLeft();
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
        throw Exception(
          'El backend devolvió HTML (no JSON). Revisa baseUrl o GET /areas?tipo=APOYO_HORAS. HTTP ${resp.statusCode}',
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
      m.horas = (m.inicio != null && m.fin != null)
          ? _calcHoras(m.inicio!, m.fin!)
          : null;
    });
  }

  void _addTrabajador() => setState(() => _trabajadores.add(_ApoyoFormModel()));

  Future<void> _loadLineasExistentes() async {
    try {
      final resp = await widget.api.get('/reportes/${widget.reporteId}/lineas');

      final body = resp.body.trimLeft();
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
        throw Exception('Backend devolvió HTML en GET /reportes/:id/lineas');
      }

      if (resp.statusCode != 200) {
        throw Exception(
          'Error cargando líneas (HTTP ${resp.statusCode}): ${resp.body}',
        );
      }

      final decoded = jsonDecode(resp.body);
      final items = (decoded is Map && decoded['items'] is List)
          ? decoded['items'] as List
          : <dynamic>[];

      // ✅ Si no hay líneas, dejamos el form con 1 vacío (como ya lo tienes)
      if (items.isEmpty) return;

      final models = <_ApoyoFormModel>[];

      TimeOfDay? parseTime(dynamic v) {
        if (v == null) return null;
        final s = v.toString(); // puede venir "08:00:00" o "08:00"
        final parts = s.split(':');
        if (parts.length < 2) return null;
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      for (final it in items.whereType<Map<String, dynamic>>()) {
        final m = _ApoyoFormModel();

        m.lineaId = (it['id'] as num?)?.toInt();
        m.trabajadorId = (it['trabajador_id'] as num?)?.toInt();

        m.codigoCtrl.text = (it['trabajador_codigo'] ?? '').toString();
        m.nombreCtrl.text = (it['trabajador_nombre'] ?? '').toString();

        m.areaId = (it['area_id'] as num?)?.toInt();
        m.areaNombre = (it['area_nombre'] ?? '').toString().isEmpty
            ? null
            : it['area_nombre'].toString();

        m.inicio = parseTime(it['hora_inicio']);
        m.fin = parseTime(it['hora_fin']);

        // horas (si viene null y hay fin, la calculamos luego igual)
        final h = it['horas'];
        if (h is num) m.horas = h.toDouble();

        // Si hay inicio+fin y horas no vino, calculamos
        if (m.inicio != null && m.fin != null && m.horas == null) {
          m.horas = _calcHoras(m.inicio!, m.fin!);
        }

        models.add(m);
      }

      if (!mounted) return;
      setState(() {
        _trabajadores
          ..clear()
          ..addAll(models);
      });
    } catch (e) {
      // No bloquees la pantalla: solo muestra error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar líneas: $e')),
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación mínima
    for (final t in _trabajadores) {
      if (t.trabajadorId == null || t.inicio == null || t.areaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escanea trabajador, selecciona hora inicio y área'),
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

        // ✅ Si no hay hora_fin, mandamos horas = null (queda pendiente)
        final double? horas = (t.fin != null)
            ? _calcHoras(t.inicio!, t.fin!)
            : null;

        final payload = <String, dynamic>{
          'trabajador_id': t.trabajadorId,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin, // puede ser null
          'horas': horas, // puede ser null
          'area_id': t.areaId,
          // ❌ tu backend no necesita "area" (usa area_id y arma area_nombre)
          // 'area': t.areaNombre,
        };

        // ✅ Si ya existe una línea en BD -> PATCH. Si no -> POST.
        late final resp;
        if (t.lineaId != null) {
          resp = await widget.api.patch(
            '/reportes/lineas/${t.lineaId}',
            payload,
          );
        } else {
          resp = await widget.api.post(
            '/reportes/${widget.reporteId}/lineas',
            payload,
          );
        }

        final body = resp.body.trimLeft();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          throw Exception(
            'El backend devolvió HTML en guardar. HTTP ${resp.statusCode}',
          );
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
        }

        // ✅ Si fue creación, guarda el linea_id para que la próxima sea PATCH
        if (t.lineaId == null) {
          final decoded = jsonDecode(resp.body);
          final newId = (decoded is Map && decoded['linea_id'] is num)
              ? (decoded['linea_id'] as num).toInt()
              : null;
          t.lineaId = newId;
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

              if (!_loadingAreas &&
                  _errorAreas == null &&
                  _areas.isNotEmpty) ...[
                for (int i = 0; i < _trabajadores.length; i++)
                  _TrabajadorCard(
                    index: i,
                    model: _trabajadores[i],
                    areas: _areas,
                    api: widget.api,
                    onPickInicio: () => _pickHora(_trabajadores[i], true),
                    onPickFin: () => _pickHora(_trabajadores[i], false),
                    onChangedArea: (a) {
                      setState(() {
                        _trabajadores[i].areaId = a.id;
                        _trabajadores[i].areaNombre = a.nombre;
                      });
                    },
                    // ✅ ESTE ES EL FIX: actualizar con setState en el padre
                    onFillFromScan: (result) {
                      setState(() {
                        final idAny = result['id'];
                        final idNum = (idAny is num)
                            ? idAny
                            : num.tryParse(idAny?.toString() ?? '');

                        _trabajadores[i].trabajadorId = (idNum == null)
                            ? null
                            : idNum.toInt();

                        final codigo = (result['codigo'] ?? '')
                            .toString()
                            .trim();
                        final dni = (result['dni'] ?? '').toString().trim();
                        final nombre = (result['nombre_completo'] ?? '')
                            .toString()
                            .trim();

                        // si viene codigo úsalo; si no viene, usa dni
                        _trabajadores[i].codigoCtrl.text = codigo.isNotEmpty
                            ? codigo
                            : dni;

                        _trabajadores[i].nombreCtrl.text = nombre;

                        debugPrint('SCAN RESULT MAP: $result');
                        debugPrint(
                          'SET trabajadorId=${_trabajadores[i].trabajadorId} codigo=${_trabajadores[i].codigoCtrl.text}',
                        );
                      });
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
  int? lineaId;
  int? trabajadorId;
  final codigoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();

  TimeOfDay? inicio;
  TimeOfDay? fin;
  double? horas;

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
    required this.api,
    required this.onFillFromScan,
  });

  final int index;
  final _ApoyoFormModel model;
  final List<_AreaItem> areas;
  final VoidCallback onPickInicio;
  final VoidCallback onPickFin;
  final void Function(_AreaItem) onChangedArea;
  final ApiClient api;

  /// callback al padre para hacer setState
  final void Function(Map<String, dynamic> result) onFillFromScan;

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
              decoration: InputDecoration(
                labelText: 'Código del trabajador',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final result = await Navigator.push<Map<String, dynamic>?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QrScannerPage(api: api),
                      ),
                    );

                    if (result == null) return;

                    // ✅ manda al padre para setState
                    onFillFromScan(result);
                  },
                ),
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
                if (id == null) return;
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
                'Total horas: ${model.horas != null ? model.horas!.toStringAsFixed(2) : '--'}',
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
