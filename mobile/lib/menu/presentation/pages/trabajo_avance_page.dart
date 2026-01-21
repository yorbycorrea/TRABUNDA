//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/trabajo_avance/models.dart';
import 'trabajo_avance_cuadrilla_detalle_page.dart';
import 'package:mobile/core/ui/notifications.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

enum _TaMode { start, edit, view }

class TrabajoAvancePage extends StatefulWidget {
  const TrabajoAvancePage({super.key, required this.api});
  final ApiClient api;

  @override
  State<TrabajoAvancePage> createState() => _TrabajoAvancePageState();
}

class _TrabajoAvancePageState extends State<TrabajoAvancePage> {
  int? _reporteId;

  bool _loading = false;
  String? _error;

  // ✅ Cabecera (UI)
  String _turno = "Día";
  DateTime _fecha = DateTime.now();
  TimeOfDay? _inicio;
  TimeOfDay? _fin;

  // Para el Card cuando existe
  TrabajoAvanceReporte? _reporteEncontrado;

  // Modo: start / edit / view
  _TaMode _mode = _TaMode.start;
  bool get _readOnly => _mode == _TaMode.view;

  List<TaCuadrilla> _cuadrillas = [];
  Map<String, double> _totales = {
    "RECEPCION": 0,
    "FILETEADO": 0,
    "APOYO_RECEPCION": 0,
  };

  late final StartTrabajoAvance _startTrabajoAvance;
  late final FetchTrabajoAvance _fetchTrabajoAvance;
  late final UpdateTrabajoAvanceHorario _updateTrabajoAvanceHorario;
  late final CreateTrabajoAvanceCuadrilla _createTrabajoAvanceCuadrilla;

  @override
  void initState() {
    super.initState();
    // Antes abrías de frente. Ahora empieza como Conteo Rápido (Start).
    _mode = _TaMode.start;
    final repository = ReportRepositoryImpl(widget.api);
    _startTrabajoAvance = StartTrabajoAvance(repository);
    _fetchTrabajoAvance = FetchTrabajoAvance(repository);
    _updateTrabajoAvanceHorario = UpdateTrabajoAvanceHorario(repository);
    _createTrabajoAvanceCuadrilla = CreateTrabajoAvanceCuadrilla(repository);
  }

  void _resetAfterSave() {
    setState(() {
      _mode = _TaMode.start;
      _reporteId = null;
      _reporteEncontrado = null;
      _inicio = null;
      _fin = null;
      _cuadrillas.clear();
      _totales = {"RECEPCION": 0, "FILETEADO": 0, "APOYO_RECEPCION": 0};
    });
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
        return AppColors.colorCard;
      case "FILETEADO":
        return AppColors.colorCard;
      case "APOYO_RECEPCION":
        return AppColors.colorCard;
      default:
        return AppColors.surface;
    }
  }

  Color _titleColorPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
      case "FILETEADO":
      case "APOYO_RECEPCION":
        return AppColors.barraNavegacion;
      default:
        return Colors.black;
    }
  }

  IconData _iconoPorTipo(String tipo) {
    switch (tipo) {
      case "RECEPCION":
        return Icons.inventory_2;
      case "FILETEADO":
        return Icons.cut;
      case "APOYO_RECEPCION":
        return Icons.groups;
      default:
        return Icons.folder;
    }
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

  void _limpiarResumen() {
    _cuadrillas = [];
    _totales = {"RECEPCION": 0, "FILETEADO": 0, "APOYO_RECEPCION": 0};
    _inicio = null;
    _fin = null;
  }

  // =========================
  // ✅ FLUJO tipo Conteo Rápido
  // =========================

  Future<void> _iniciarReporte() async {
    setState(() {
      _loading = true;
      _error = null;
      _reporteEncontrado = null;
      _reporteId = null;
      _limpiarResumen();
    });

    try {
      final result = await _startTrabajoAvance.call(
        fecha: _fecha,
        turno: _turno,
      );

      if (result.existente) {
        // ✅ MODO START + Card con botones Ver/Continuar
        setState(() {
          _mode = _TaMode.start;
          _reporteEncontrado = result.reporte;
          _reporteId = result.reporte.id;
        });
        return;
      }

      // ✅ No existía: entra directo a EDIT y carga resumen
      setState(() {
        _reporteId = result.reporte.id;
        _mode = _TaMode.edit;
      });
      await _loadResumen();
    } catch (e) {
      setState(() => _error = "Error iniciando: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verReporte() async {
    if (_reporteId == null) return;
    setState(() {
      _mode = _TaMode.view;
      _error = null;
      _loading = true;
      _limpiarResumen();
    });

    try {
      await _loadResumen();
    } catch (e) {
      setState(() => _error = "Error cargando: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _continuarEditando() async {
    if (_reporteId == null) return;
    setState(() {
      _mode = _TaMode.edit;
      _error = null;
      _loading = true;
      _limpiarResumen();
    });

    try {
      await _loadResumen();
    } catch (e) {
      setState(() => _error = "Error cargando: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _volverStart() {
    setState(() {
      _mode = _TaMode.start;
      _error = null;
      _reporteEncontrado = null;
      _reporteId = null;
      _loading = false;
      _limpiarResumen();
    });
  }

  // =========================
  // ✅ Cargar resumen (solo cuando ya hay reporteId)
  // =========================

  Future<void> _loadResumen() async {
    if (_reporteId == null) return;

    final resumen = await _fetchTrabajoAvance.call(_reporteId!);

    setState(() {
      _totales = resumen.totales;
      _cuadrillas = resumen.cuadrillas;

      _inicio = _parseTime(resumen.reporte?.horaInicio);
      _fin = _parseTime(resumen.reporte?.horaFin);
    });
  }

  List<TaCuadrilla> _porTipo(String tipo) =>
      _cuadrillas.where((c) => c.tipo == tipo).toList();

  // =========================
  // ✅ UI header (en START no debe auto-open)
  // =========================

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      _fecha = picked;
      // en start: no consultamos nada hasta que presione "Iniciar"
      if (_mode == _TaMode.start) _reporteEncontrado = null;
    });
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
          Row(
            children: [
              _infoCard(
                label: "Fecha",
                value: _fmtFechaUi(_fecha),
                icon: Icons.calendar_month,
                onTap: _mode == _TaMode.start
                    ? _pickFecha
                    : () {}, // bloquea cambio en edit/view
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
                                onChanged: _mode == _TaMode.start
                                    ? (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _turno = v;
                                          _reporteEncontrado =
                                              null; // limpia card al cambiar
                                        });
                                      }
                                    : null, // bloquea cambio en edit/view
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
  // ✅ Guardar (solo en EDIT)
  // =========================

  Future<void> _guardarHorarioGlobal() async {
    if (_reporteId == null) return;

    try {
      await _updateTrabajoAvanceHorario.call(
        reporteId: _reporteId!,
        inicio: _inicio,
        fin: _fin,
      );

      if (!mounted) return;

      showSavedToast(context, message: 'Guardado correctamente');

      _resetAfterSave();
    } catch (e) {
      if (!mounted) return;
      showSavedToast(context, message: 'Error guardando: $e');
    }
  }

  Widget _bottomGuardar() {
    if (_mode != _TaMode.edit) return const SizedBox.shrink(); // SOLO en edit

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
  // ✅ Crear cuadrilla (bloqueado en VIEW)
  // =========================

  Future<void> _crearCuadrillaDialog(String tipo) async {
    if (_readOnly) return; // ✅ bloqueo
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

    await _createTrabajoAvanceCuadrilla.call(
      reporteId: _reporteId!,
      tipo: tipo,
      nombre: ctrl.text.trim(),
      apoyoDeCuadrillaId: apoyoDeId,
    );

    await _loadResumen();
  }

  // =========================
  // ✅ Sección (bloquea + y bloquea tap en VIEW si quieres)
  // =========================

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
                  onPressed: _readOnly
                      ? null
                      : () => _crearCuadrillaDialog(tipo),
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
                subtitle: null,
                trailing: Text("${c.produccionKg.toStringAsFixed(2)} kg"),
                onTap: _readOnly
                    ? null // ✅ en VER no entra a detalle (así garantizas solo lectura)
                    : () async {
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

  // =========================
  // ✅ UI START: botón iniciar + Card (si existe)
  // =========================

  Widget _startActions() {
    final rep = _reporteEncontrado;
    final cerrado = (rep?.estado ?? '') == 'CERRADO';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          SizedBox(
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
              onPressed: _loading ? null : _iniciarReporte,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                "Iniciar reporte",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (rep != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ya existe un reporte para esta fecha y turno.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("ID: ${rep.id}  •  Estado: ${rep.estado}"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _verReporte,
                            icon: const Icon(Icons.visibility),
                            label: const Text("Ver reporte"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _continuarEditando,
                            // onPressed: cerrado? null: _continuarEditando => esto es para que se desabilite el reporte cuando ya se guarda y no se pueda seguir editando
                            icon: const Icon(Icons.edit),
                            label: const Text("Continuar"),
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
    );
  }

  // =========================
  // ✅ UI principal
  // =========================

  @override
  Widget build(BuildContext context) {
    final isStart = _mode == _TaMode.start;

    return Scaffold(
      backgroundColor: AppColors.fondoPantalla,
      appBar: AppBar(
        backgroundColor: AppColors.barraNavegacion,
        foregroundColor: Colors.white,
        title: const Text("Trabajo por Avance"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_mode == _TaMode.start) {
              debugPrint('canPop = ${Navigator.canPop(context)}');
              Navigator.pop(context);
            } else {
              _volverStart();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (isStart) {
                // en start, solo limpia el card/error
                setState(() {
                  _error = null;
                  _reporteEncontrado = null;
                });
              } else {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                try {
                  await _loadResumen();
                } catch (e) {
                  setState(() => _error = "Error recargando: $e");
                } finally {
                  setState(() => _loading = false);
                }
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              children: [
                _headerUi(),

                if (_mode == _TaMode.start) ...[
                  _startActions(),
                ] else ...[
                  _seccion(
                    "Recepción",
                    "RECEPCION",
                    _totales["RECEPCION"] ?? 0,
                  ),
                  _seccion(
                    "Fileteado",
                    "FILETEADO",
                    _totales["FILETEADO"] ?? 0,
                  ),
                  _seccion(
                    "Apoyos de Recepción",
                    "APOYO_RECEPCION",
                    _totales["APOYO_RECEPCION"] ?? 0,
                  ),
                  _bottomGuardar(),
                ],
              ],
            ),
    );
  }
}
