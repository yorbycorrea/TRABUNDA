import 'package:mobile/core/ui/app_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/widgets/qr_scanner.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';
import 'package:mobile/domain/reports/usecase/apoyos_horas_use_cases.dart';

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

  late final FetchApoyoAreas _fetchApoyoAreas;
  late final FetchApoyoLineas _fetchApoyoLineas;
  late final UpsertApoyoHorasLinea _upsertApoyoHorasLinea;

  final _calculateHoras = CalculateHoras();
  final _validateApoyoHorasLineas = ValidateApoyoHorasLineas();
  final _mapQrToApoyoHorasModel = MapQrToApoyoHorasModel();

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _fetchApoyoAreas = FetchApoyoAreas(repository);
    _fetchApoyoLineas = FetchApoyoLineas(repository);
    _upsertApoyoHorasLinea = UpsertApoyoHorasLinea(repository);
    _loadAreas();
    _loadLineasExistentes();
  }

  @override
  void dispose() {
    for (final t in _trabajadores) {
      t.codigoCtrl.dispose();
      t.nombreCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loadingAreas = true;
      _errorAreas = null;
      _areas = [];
    });

    try {
      final list = await _fetchApoyoAreas.call();

      if (!mounted) return;
      setState(() {
        _areas = list
            .map((e) => _AreaItem(id: e.id, nombre: e.nombre, activo: e.activo))
            .toList();
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

  List<ApoyoHorasLineaInput> _buildLineasInput() {
    return _trabajadores
        .map(
          (t) => ApoyoHorasLineaInput(
            trabajadorId: t.trabajadorId,
            codigo: t.codigoCtrl.text.trim(),
            inicio: t.inicio,
            areaId: t.areaId,
          ),
        )
        .toList();
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
          ? _calculateHoras(m.inicio!, m.fin!)
          : null;
    });
  }

  void _addTrabajador() => setState(() => _trabajadores.add(_ApoyoFormModel()));

  Future<void> _loadLineasExistentes() async {
    try {
      final items = await _fetchApoyoLineas.call(widget.reporteId);

      if (items.isEmpty) return;

      final models = <_ApoyoFormModel>[];

      TimeOfDay? parseTime(dynamic v) {
        if (v == null) return null;
        final s = v.toString(); // "08:00:00" o "08:00"
        final parts = s.split(':');
        if (parts.length < 2) return null;
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      for (final it in items) {
        final m = _ApoyoFormModel();

        m.lineaId = it.id;
        m.trabajadorId = it.trabajadorId;

        m.codigoCtrl.text = it.trabajadorCodigo;
        m.nombreCtrl.text = it.trabajadorNombre;

        m.areaId = it.areaId;
        m.areaNombre = (it.areaNombre ?? '').isEmpty ? null : it.areaNombre;

        m.inicio = parseTime(it.horaInicio);
        m.fin = parseTime(it.horaFin);

        final horasValue = it.horas;
        if (horasValue != null) {
          m.horas = horasValue;
        }

        if (m.horas == null && m.inicio != null && m.fin != null) {
          m.horas = _calculateHoras(m.inicio!, m.fin!);
        }

        models.add(m);
      }

      if (!mounted) return;
      setState(() {
        // limpiar los controllers viejos
        for (final t in _trabajadores) {
          t.codigoCtrl.dispose();
          t.nombreCtrl.dispose();
        }
        _trabajadores
          ..clear()
          ..addAll(models);
      });
    } catch (e) {
      if (!mounted) return;
      AppNotify.error(context, 'Error', 'No se pudieron cargar líneas: $e');
    }
  }

  String _fmt(TimeOfDay? t) {
    if (t == null) return 'null';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final validationMessage = _validateApoyoHorasLineas(_buildLineasInput());
    if (validationMessage != null) {
      AppNotify.warning(context, 'Validación', validationMessage);
      return;
    }

    setState(() => _saving = true);

    try {
      for (final t in _trabajadores) {
        final double? horas =
            t.horas ??
            ((t.inicio != null && t.fin != null)
                ? _calculateHoras(t.inicio!, t.fin!)
                : null);
        // ✅ LOG: lo que vas a mandar (lo más importante para “en espera”)
        debugPrint('🟡 UPSERT LINEA -> reporteId=${widget.reporteId}');
        debugPrint('   lineaId=${t.lineaId}');
        debugPrint('   trabajadorId=${t.trabajadorId}');
        debugPrint('   areaId=${t.areaId}');
        debugPrint('   inicio=${_fmt(t.inicio)}');
        debugPrint(
          '   fin=${_fmt(t.fin)}  (si es null => DEBE quedar en espera)',
        );
        debugPrint('   horas=$horas');

        if (t.lineaId == null) {
          t.lineaId = await _upsertApoyoHorasLinea.call(
            lineaId: t.lineaId,
            reporteId: widget.reporteId,
            trabajadorId: t.trabajadorId!,
            inicio: t.inicio!,
            fin: t.fin,
            horas: horas,
            areaId: t.areaId!,
          );
        } else {
          await _upsertApoyoHorasLinea.call(
            lineaId: t.lineaId,
            reporteId: widget.reporteId,
            trabajadorId: t.trabajadorId!,
            inicio: t.inicio!,
            fin: t.fin,
            horas: horas,
            areaId: t.areaId!,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppNotify.error(context, 'Error', 'Error guardando: $e');
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

                    // ✅ AQUÍ: validación anti-duplicado al escanear
                    onFillFromScan: (result) {
                      final mapped = _mapQrToApoyoHorasModel(result);

                      // ✅ si ya existe en otra fila -> no permitir
                      if (_validateApoyoHorasLineas.existsDuplicate(
                        lineas: _buildLineasInput(),
                        trabajadorId: mapped.trabajadorId,
                        codigo: mapped.codigo,
                        exceptIndex: i,
                      )) {
                        AppNotify.warning(
                          context,
                          'Duplicado',
                          'Ese trabajador ya fue agregado en este reporte.',
                        );
                        return;
                      }

                      setState(() {
                        _trabajadores[i].trabajadorId = mapped.trabajadorId;
                        _trabajadores[i].codigoCtrl.text = mapped.codigo;
                        _trabajadores[i].nombreCtrl.text = mapped.nombre;

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
  _ApoyoFormModel({this.horas});

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
