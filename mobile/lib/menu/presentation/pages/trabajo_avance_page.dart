import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/trabajo_avance/models.dart';
import 'trabajo_avance_cuadrilla_detalle_page.dart';
import 'package:mobile/core/ui/notifications.dart';

class TrabajoAvancePage extends StatefulWidget {
  const TrabajoAvancePage({super.key, required this.api});
  final ApiClient api;

  @override
  State<TrabajoAvancePage> createState() => _TrabajoAvancePageState();
}

class _TrabajoAvancePageState extends State<TrabajoAvancePage> {
  int? _reporteId;
  bool _loading = true;
  String? _error;

  // ✅ Cabecera (UI)
  String _turno = "Día";
  DateTime _fecha = DateTime.now();
  TimeOfDay? _inicio;
  TimeOfDay? _fin;

  List<TaCuadrilla> _cuadrillas = [];
  Map<String, double> _totales = {
    "RECEPCION": 0,
    "FILETEADO": 0,
    "APOYO_RECEPCION": 0,
  };

  @override
  void initState() {
    super.initState();
    _openAndLoad();
  }

  String _fmtFechaApi(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day"; // YYYY-MM-DD
  }

  String _fmtFechaUi(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final y = d.year.toString().padLeft(4, '0');
    return "$day/$m/$y"; // DD/MM/YYYY
  }

  Color _backgroundPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
        return AppColors.colorCard; // celeste claro
      case "FILETEADO":
        return AppColors.colorCard; // azul suave
      case "APOYO_RECEPCION":
        return AppColors.colorCard; // gris / verde claro
      default:
        return AppColors.surface;
    }
  }

  BorderSide _borderPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
        return BorderSide(color: AppColors.bordeColorcard, width: 1);
      case "FILETEADO":
        return BorderSide(color: AppColors.bordeColorcard, width: 1);
      case "APOYO_RECEPCION":
        return BorderSide(color: AppColors.bordeColorcard, width: 1);
      default:
        return BorderSide.none;
    }
  }

  Color _titleColorPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
        return AppColors.barraNavegacion; // azul / celeste
      case "FILETEADO":
        return AppColors.barraNavegacion; // teal / verde
      case "APOYO_RECEPCION":
        return AppColors.barraNavegacion; // gris / verde suave
      default:
        return Colors.black;
    }
  }

  IconData _iconoPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
        return Icons.inventory_2; // caja
      case "FILETEADO":
        return Icons.cut; // cuchillo
      case "APOYO_RECEPCION":
        return Icons.groups; // apoyo
      default:
        return Icons.folder;
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String? _fmtTime(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return "$h:$m:00";
  }

  Future<void> _openAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final openResp = await widget.api.get(
        '/reportes/trabajo-avance/open?fecha=${_fmtFechaApi(_fecha)}&turno=${Uri.encodeQueryComponent(_turno)}',
      );
      final openJson = jsonDecode(openResp.body) as Map<String, dynamic>;
      _reporteId = (openJson['reporte']['id'] as num).toInt();

      await _loadResumen();
    } catch (e) {
      setState(() => _error = "Error cargando: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadResumen() async {
    if (_reporteId == null) return;

    final resp = await widget.api.get(
      '/reportes/trabajo-avance/$_reporteId/resumen',
    );
    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    final rep =
        (j['reporte'] as Map<String, dynamic>?); // debe venir del backend
    final tot = (j['totales'] as Map<String, dynamic>);
    final cuad = (j['cuadrillas'] as List).cast<Map<String, dynamic>>();

    setState(() {
      _totales = {
        "RECEPCION": _toDouble(tot["RECEPCION"]),
        "FILETEADO": _toDouble(tot["FILETEADO"]),
        "APOYO_RECEPCION": _toDouble(tot["APOYO_RECEPCION"]),
      };
      _cuadrillas = cuad.map(TaCuadrilla.fromJson).toList();

      _inicio = _parseTime(rep?['hora_inicio']?.toString());
      _fin = _parseTime(rep?['hora_fin']?.toString());
    });
  }

  List<TaCuadrilla> _porTipo(String tipo) =>
      _cuadrillas.where((c) => c.tipo == tipo).toList();

  // =========================
  // ✅ UI: Fecha / Turno / Horas (sin botón guardar aquí)
  // =========================

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null) return;

    setState(() => _fecha = picked);
    await _openAndLoad();
  }

  Future<void> _pickInicio() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _inicio ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _inicio = picked);
  }

  Future<void> _pickFin() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _fin ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _fin = picked);
  }

  Widget _infoCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null) Icon(icon, color: Colors.black54, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerUi() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          // Fecha + Turno
          Row(
            children: [
              _infoCard(
                label: "Fecha",
                value: _fmtFechaUi(_fecha),
                icon: Icons.calendar_month,
                onTap: _pickFecha,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Turno",
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _turno,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: "Día",
                                    child: Text("Dia"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Noche",
                                    child: Text("Noche"),
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  setState(() => _turno = v);
                                  await _openAndLoad();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // =========================
  // ✅ Guardar (abajo de TODO)
  // =========================

  Future<void> _guardarHorarioGlobal() async {
    if (_reporteId == null) return;

    try {
      final resp = await widget.api.put(
        // ✅ Debe existir en backend: PUT /reportes/trabajo-avance/:reporteId
        '/reportes/trabajo-avance/$_reporteId',
        {"hora_inicio": _fmtTime(_inicio), "hora_fin": _fmtTime(_fin)},
      );

      if (!mounted) return;

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        showSavedToast(context, message: 'No se pudo guardar');
        return;
      }

      showSavedToast(context, message: 'Guardado correctamente');
      await _loadResumen();
    } catch (e) {
      if (!mounted) return;
      showSavedToast(context, message: 'Error guardando: $e');
    }
  }

  Widget _bottomGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.barraNavegacion,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.bordeColorcard, width: 1),
            ),
          ),
          onPressed: _guardarHorarioGlobal,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text(
            "Guardar",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // =========================
  // Secciones (sin hora inicio/fin por cuadrilla)
  // =========================

  Future<void> _crearCuadrillaDialog(String tipo) async {
    final ctrl = TextEditingController();
    int? apoyoDeId;

    final recepciones = _porTipo("RECEPCION");

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          tipo == "APOYO_RECEPCION"
              ? "Nuevo apoyo de recepción"
              : "Nueva cuadrilla",
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: "Nombre (ej: CLEY, TOLVA 1, F-11)",
              ),
            ),
            if (tipo == "APOYO_RECEPCION") ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: apoyoDeId,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("Sin vincular"),
                  ),
                  ...recepciones.map(
                    (r) => DropdownMenuItem<int?>(
                      value: r.id,
                      child: Text("Apoya a: ${r.nombre}"),
                    ),
                  ),
                ],
                onChanged: (v) => apoyoDeId = v,
                decoration: const InputDecoration(
                  labelText: "Vincular a cuadrilla recepción",
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Crear"),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (_reporteId == null) return;

    final body = {
      "tipo": tipo,
      "nombre": ctrl.text.trim(),
      "apoyoDeCuadrillaId": apoyoDeId,
    };

    final resp = await widget.api.post(
      '/reportes/trabajo-avance/$_reporteId/cuadrillas',
      body,
    );

    final j = jsonDecode(resp.body);
    if (j['ok'] == true) {
      await _loadResumen();
    }
  }

  Widget _seccion(String titulo, String tipo, double totalKg) {
    final items = _porTipo(tipo);

    return Card(
      color: _backgroundPorTipo(tipo),
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconoPorTipo(tipo),
                  size: 22,
                  color: _titleColorPorTipo(tipo),
                ),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _titleColorPorTipo(tipo),
                  ),
                ),
                const Spacer(),
                Text(
                  "${totalKg.toStringAsFixed(2)} kg",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: AppColors.coloriconSuma,
                  onPressed: () => _crearCuadrillaDialog(tipo),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text(
                "Sin registros",
                style: TextStyle(color: AppColors.testoSecundario),
              ),
            for (final c in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                // ✅ ya NO mostramos horario por cuadrilla
                subtitle: null,
                trailing: Text("${c.produccionKg.toStringAsFixed(2)} kg"),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrabajoAvanceCuadrillaDetallePage(
                        api: widget.api,
                        cuadrillaId: c.id,
                      ),
                    ),
                  );
                  await _loadResumen();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoPantalla,
      appBar: AppBar(
        backgroundColor: AppColors.barraNavegacion,
        foregroundColor: Colors.white,
        title: const Text("Trabajo por Avance"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _openAndLoad),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              children: [
                // ✅ header como tu diseño (sin botón guardar aquí)
                _headerUi(),

                _seccion("Recepción", "RECEPCION", _totales["RECEPCION"] ?? 0),
                _seccion("Fileteado", "FILETEADO", _totales["FILETEADO"] ?? 0),
                _seccion(
                  "Apoyos de Recepción",
                  "APOYO_RECEPCION",
                  _totales["APOYO_RECEPCION"] ?? 0,
                ),

                // ✅ botón guardar abajo de TODO
                _bottomGuardar(),
              ],
            ),
    );
  }
}
