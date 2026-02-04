import 'package:mobile/core/ui/app_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/widgets/qr_scanner.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';
import 'package:mobile/domain/reports/usecase/saneamiento_use_cases.dart';

class SaneamientoBackendPage extends StatefulWidget {
  const SaneamientoBackendPage({
    super.key,
    required this.api,
    required this.reporteId,
    required this.fecha,
    required this.turno,
    required this.saneador,
    this.readOnly = false,
  });

  final ApiClient api;
  final int reporteId;
  final DateTime fecha;
  final String turno;
  final String saneador;
  final bool readOnly;

  @override
  State<SaneamientoBackendPage> createState() => _SaneamientoBackendPageState();
}

class _SaneamientoBackendPageState extends State<SaneamientoBackendPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Puedes permitir varios trabajadores en saneamiento (igual que apoyo horas)
  final List<_SaneaFormModel> _items = [_SaneaFormModel()];

  late final FetchSaneamientoLineas _fetchSaneamientoLineas;
  late final UpsertSaneamientoLinea _upsertSaneamientoLinea;
  late final CalculateHoras _calculateHoras;
  late final ValidateSaneamientoLineas _validateSaneamientoLineas;

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _fetchSaneamientoLineas = FetchSaneamientoLineas(repository);
    _upsertSaneamientoLinea = UpsertSaneamientoLinea(repository);
    _calculateHoras = CalculateHoras();
    _validateSaneamientoLineas = const ValidateSaneamientoLineas();
    _loadLineasExistentes();
  }

  @override
  void dispose() {
    for (final it in _items) {
      it.codigoCtrl.dispose();
      it.nombreCtrl.dispose();
      it.laboresCtrl.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay? t) => t == null
      ? 'null'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _nowTime() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }

  List<SaneamientoLineaValidation> _mapValidations() {
    return _items.map((item) {
      final codigoCtrl = item.codigoCtrl.text.trim();
      final codigo = codigoCtrl.isNotEmpty
          ? codigoCtrl
          : (item.trabajadorCodigo ?? '').trim();
      item.trabajadorCodigo = codigo;
      item.trabajadorNombre = item.nombreCtrl.text.trim();
      return SaneamientoLineaValidation(
        trabajadorId: item.trabajadorId,
        trabajadorCodigo: codigo,
        inicio: item.inicio,
      );
    }).toList();
  }

  Future<void> _pickHora(_SaneaFormModel m, bool inicio) async {
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

  void _addTrabajador() => setState(() => _items.add(_SaneaFormModel()));

  Future<void> _loadLineasExistentes() async {
    try {
      final items = await _fetchSaneamientoLineas.call(widget.reporteId);

      if (items.isEmpty) return;

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

      final models = <_SaneaFormModel>[];
      for (final it in items) {
        final m = _SaneaFormModel();
        m.lineaId = it.id;
        m.trabajadorId = it.trabajadorId;
        m.trabajadorCodigo = it.trabajadorCodigo;
        m.trabajadorNombre = it.trabajadorNombre;
        m.trabajadorDocumento = '';

        m.codigoCtrl.text = it.trabajadorCodigo;
        m.nombreCtrl.text = it.trabajadorNombre;

        m.inicio = parseTime(it.horaInicio);
        m.fin = parseTime(it.horaFin);

        final horasValue = it.horas;
        if (horasValue != null) {
          m.horas = horasValue;
        } else if (m.inicio != null && m.fin != null) {
          m.horas = _calculateHoras(m.inicio!, m.fin!);
        }

        m.laboresCtrl.text = it.labores;

        models.add(m);
      }

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(models);
      });
    } catch (_) {
      // Silencioso
    }
  }

  Future<void> _guardar() async {
    if (widget.readOnly) return;
    if (!_formKey.currentState!.validate()) return;

    for (final item in _items) {
      debugPrint(
        '[DEBUG GUARDAR] trabajadorId=${item.trabajadorId} '
        'trabajadorCodigo=${item.trabajadorCodigo} '
        'inicio=${_formatTime(item.inicio)} '
        'lineaId=${item.lineaId} '
        'codigoCtrl=${item.codigoCtrl.text.trim()} '
        'nombreCtrl=${item.nombreCtrl.text.trim()}',
      );
    }

    final validationMessage = _validateSaneamientoLineas.validarMinimo(
      _mapValidations(),
    );
    if (validationMessage != null) {
      AppNotify.warning(context, 'Validación', validationMessage);
      return;
    }

    setState(() => _saving = true);

    try {
      for (final t in _items) {
        final horas =
            t.horas ??
            ((t.inicio != null && t.fin != null)
                ? _calculateHoras(t.inicio!, t.fin!)
                : null);

        // si creó línea, guarda ID
        if (t.lineaId == null) {
          debugPrint(
            'SANEAMIENTO upsert (crear) trabajadorCodigo=${t.codigoCtrl.text.trim()} '
            'trabajadorNombre=${t.nombreCtrl.text.trim()} '
            'trabajadorDocumento=${t.dniQr?.trim() ?? ''} '
            'horaInicio=${_formatTime(t.inicio)} '
            'labores=${t.laboresCtrl.text.trim()}',
          );
          t.lineaId = await _upsertSaneamientoLinea.call(
            lineaId: t.lineaId,
            reporteId: widget.reporteId,
            trabajadorId: t.trabajadorId!,
            inicio: t.inicio!,
            fin: t.fin,
            horas: horas,
            labores: t.laboresCtrl.text,
          );
        } else {
          debugPrint(
            'SANEAMIENTO upsert (actualizar) trabajadorCodigo=${t.codigoCtrl.text.trim()} '
            'trabajadorNombre=${t.nombreCtrl.text.trim()} '
            'trabajadorDocumento=${t.dniQr?.trim() ?? ''} '
            'horaInicio=${_formatTime(t.inicio)} '
            'labores=${t.laboresCtrl.text.trim()}',
          );
          await _upsertSaneamientoLinea.call(
            lineaId: t.lineaId,
            reporteId: widget.reporteId,
            trabajadorId: t.trabajadorId!,
            inicio: t.inicio!,
            fin: t.fin,
            horas: horas,
            labores: t.laboresCtrl.text,
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
      appBar: AppBar(
        title: const Text('Saneamiento · Detalle'),
        actions: widget.readOnly
            ? null
            : [
                IconButton(
                  onPressed: _saving ? null : _guardar,
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Reporte #${widget.reporteId}'),
              Text('Fecha: $fechaStr'),
              Text('Turno: ${widget.turno}'),
              Text('Saneamiento: ${widget.saneador}'),
              const SizedBox(height: 10),
              const Divider(),

              for (int i = 0; i < _items.length; i++)
                _SaneamientoCard(
                  index: i,
                  model: _items[i],
                  api: widget.api,
                  readOnly: widget.readOnly,
                  onPickInicio: () => _pickHora(_items[i], true),
                  onPickFin: () => _pickHora(_items[i], false),
                  onFillFromScan: (result) {
                    debugPrint(
                      'SANEAMIENTO QR raw result=${result.toString()}',
                    );
                    final workerRaw = result['worker'];
                    final worker = workerRaw is Map
                        ? Map<String, dynamic>.from(workerRaw)
                        : null;
                    final idAny = result['id'] ?? worker?['id'];
                    final idNum = (idAny is num)
                        ? idAny
                        : num.tryParse(idAny?.toString() ?? '');
                    var newTrabId = (idNum == null) ? null : idNum.toInt();
                    final codigo = (worker?['codigo'] ?? '').toString().trim();
                    final dni = (result['dni'] ?? worker?['dni'] ?? '')
                        .toString()
                        .trim();
                    final nombre = (worker?['nombre'] ?? '').toString().trim();
                    final codigoFinal = codigo.isNotEmpty ? codigo : dni;

                    setState(() {
                      if (newTrabId == null) {
                        newTrabId = int.tryParse(codigoFinal);
                      }

                      final validationBefore = _mapValidations();
                      debugPrint(
                        'SANEAMIENTO QR pre-setState codigo=$codigoFinal '
                        'nombre=$nombre lineaId=${_items[i].lineaId} '
                        'trabajadorId=$newTrabId inicio=${_formatTime(_items[i].inicio)} '
                        'validations=$validationBefore',
                      );

                      // ✅ Validación duplicado
                      if (_validateSaneamientoLineas.yaExisteTrabajador(
                        items: _mapValidations(),
                        trabajadorId: newTrabId,
                        codigo: codigoFinal,
                        exceptIndex: i,
                      )) {
                        AppNotify.warning(
                          context,
                          'Duplicado',
                          'Ese trabajador ya está agregado.',
                        );
                        return;
                      }

                      final m = _items[i];

                      m.trabajadorId = newTrabId;
                      m.trabajadorCodigo = codigoFinal;
                      m.trabajadorNombre = nombre;
                      m.trabajadorDocumento = dni;
                      m.codigoCtrl.text = codigoFinal;
                      m.nombreCtrl.text = nombre;
                      m.dniQr = dni;

                      debugPrint(
                        'TEMP LOG (remover luego) index=$i lineaId=${m.lineaId} codigo=${m.codigoCtrl.text}',
                      );
                      debugPrint(
                        'TEMP LOG (remover luego) index=$i lineaId=${m.lineaId} nombre=${m.nombreCtrl.text}',
                      );

                      // ✅ NUEVO: poner hora inicio automática si está vacía
                      if (m.inicio == null) {
                        m.inicio = _nowTime();
                      }

                      // ✅ opcional: recalcular horas si ya hay fin
                      m.horas = (m.inicio != null && m.fin != null)
                          ? _calculateHoras(m.inicio!, m.fin!)
                          : null;
                    });

                    final validationAfter = _mapValidations();
                    debugPrint(
                      'SANEAMIENTO QR post-setState codigo=$codigoFinal '
                      'nombre=$nombre lineaId=${_items[i].lineaId} '
                      'trabajadorId=$newTrabId inicio=${_formatTime(_items[i].inicio)} '
                      'validations=$validationAfter',
                    );
                  },
                ),

              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: widget.readOnly ? null : _addTrabajador,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Agregar trabajador'),
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.readOnly)
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar y volver'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaneaFormModel {
  int? lineaId;
  int? trabajadorId;
  String? trabajadorCodigo;
  String? trabajadorNombre;
  String? trabajadorDocumento;
  String? dniQr;

  final codigoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final laboresCtrl = TextEditingController();

  TimeOfDay? inicio;
  TimeOfDay? fin;
  double? horas;
}

class _SaneamientoCard extends StatelessWidget {
  const _SaneamientoCard({
    required this.index,
    required this.model,
    required this.api,
    required this.onPickInicio,
    required this.onPickFin,
    required this.onFillFromScan,
    required this.readOnly,
  });

  final int index;
  final _SaneaFormModel model;
  final ApiClient api;
  final bool readOnly;
  final VoidCallback onPickInicio;
  final VoidCallback onPickFin;
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
                    onTap: readOnly
                        ? null
                        : (model.inicio == null)
                        ? onPickInicio
                        : () {
                            AppNotify.warning(
                              context,
                              'Atención',
                              'La hora inicio se registra al escanear y no se puede cambiar.',
                            );
                          },
                    locked: readOnly || model.inicio != null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HoraBox(
                    label: 'Hora fin',
                    value: _horaText(model.fin),
                    onTap: readOnly ? null : onPickFin,
                    locked: readOnly,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: model.codigoCtrl,
              keyboardType: TextInputType.number,
              readOnly: readOnly,
              decoration: InputDecoration(
                labelText: 'Código del trabajador',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: readOnly
                      ? null
                      : () async {
                          final result =
                              await Navigator.push<Map<String, dynamic>?>(
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
              readOnly: true,
            ),

            const SizedBox(height: 14),

            // ✅ ESTE ES EL CAMPO QUE MARCASTE (Labores realizadas)
            TextFormField(
              controller: model.laboresCtrl,
              maxLines: 3,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'Labores realizadas',
                prefixIcon: Icon(Icons.work_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                // Si quieres hacerlo obligatorio, descomenta:
                // if (v == null || v.trim().isEmpty) return 'Describe las labores';
                return null;
              },
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
    this.onTap,
    this.locked = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.65 : 1.0,
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
      ),
    );
  }
}
