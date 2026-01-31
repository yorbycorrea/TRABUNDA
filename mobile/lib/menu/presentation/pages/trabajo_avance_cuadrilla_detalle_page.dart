import 'package:mobile/core/ui/app_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/trabajo_avance/models.dart';
import 'package:mobile/core/widgets/qr_scanner.dart';
import 'package:mobile/core/ui/notifications.dart';
import 'package:mobile/domain/reports/report_repository_impl.dart';
import 'package:mobile/domain/reports/usecase/report_use_cases.dart';

class TrabajoAvanceCuadrillaDetallePage extends StatefulWidget {
  const TrabajoAvanceCuadrillaDetallePage({
    super.key,
    required this.api,
    required this.cuadrillaId,
  });

  final ApiClient api;
  final int cuadrillaId;

  @override
  State<TrabajoAvanceCuadrillaDetallePage> createState() =>
      _TrabajoAvanceCuadrillaDetallePageState();
}

class _TrabajoAvanceCuadrillaDetallePageState
    extends State<TrabajoAvanceCuadrillaDetallePage> {
  bool _loading = true;
  String? _error;

  TaCuadrilla? _cuadrilla;
  List<TaTrabajador> _trabajadores = [];

  final _kgCtrl = TextEditingController();

  TimeOfDay? _inicio;
  TimeOfDay? _fin;

  late final FetchTrabajoAvanceCuadrillaDetalle _fetchDetalle;
  late final UpdateTrabajoAvanceCuadrilla _updateCuadrilla;
  late final AddTrabajoAvanceTrabajador _addTrabajador;
  late final DeleteTrabajoAvanceTrabajador _deleteTrabajadorUseCase;

  @override
  void initState() {
    super.initState();
    final repository = ReportRepositoryImpl(widget.api);
    _fetchDetalle = FetchTrabajoAvanceCuadrillaDetalle(repository);
    _updateCuadrilla = UpdateTrabajoAvanceCuadrilla(repository);
    _addTrabajador = AddTrabajoAvanceTrabajador(repository);
    _deleteTrabajadorUseCase = DeleteTrabajoAvanceTrabajador(repository);
    _load();
  }

  @override
  void dispose() {
    _kgCtrl.dispose();
    super.dispose();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detalle = await _fetchDetalle.call(widget.cuadrillaId);
      final c = detalle.cuadrilla;
      final t = detalle.trabajadores;

      setState(() {
        _cuadrilla = c;
        _trabajadores = t;
        _inicio = _parseTime(c.horaInicio);
        _fin = _parseTime(c.horaFin);
        _kgCtrl.text = c.produccionKg.toStringAsFixed(2);
      });
    } catch (e) {
      setState(() => _error = "Error cargando: $e");
    } finally {
      setState(() => _loading = false);
    }
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

  Future<void> _guardarCabecera() async {
    final kg = double.tryParse(_kgCtrl.text.replaceAll(",", ".")) ?? 0;

    try {
      await _updateCuadrilla.call(
        cuadrillaId: widget.cuadrillaId,
        inicio: _inicio,
        fin: _fin,
        produccionKg: kg,
      );

      if (!mounted) return;

      showSavedToast(context, message: 'Guardado correctamente');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSavedToast(context, message: 'Error guardando: $e');
    }
  }

  Future<void> _scanQrAndAdd() async {
    debugPrint('ABRIENDO SCANNER...');

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerPage(api: widget.api, pickOnly: true),
      ),
    );

    debugPrint('SCANNER RESULT: $res');

    if (!mounted || res == null) return;

    if (res is! Map<String, dynamic>) {
      AppNotify.warning(context, 'Atención', 'Resultado inválido del scanner');
      return;
    }

    final worker = res['worker'];
    final workerIdAny = res['id'] ?? (worker is Map ? worker['id'] : null);
    final workerIdNum = (workerIdAny is num)
        ? workerIdAny
        : num.tryParse(workerIdAny?.toString() ?? '');
    final workerId = workerIdNum?.toInt();

    var codigo = (res['codigo'] ?? '').toString().trim();
    if (codigo.isEmpty && worker is Map) {
      codigo = (worker['codigo'] ?? '').toString().trim();
    }
    final nombre = (res['nombre_completo'] ?? res['nombre'] ?? '')
        .toString()
        .trim();

    debugPrint('QR values -> codigo=$codigo nombre=$nombre workerId=$workerId');

    if (codigo.isEmpty) {
      AppNotify.warning(
        context,
        'Atención',
        'El trabajador no tiene código válido',
      );
      return;
    }

    try {
      await _addTrabajador.call(
        cuadrillaId: widget.cuadrillaId,
        codigo: codigo,
      );

      await _load();

      AppNotify.success(context, 'Agregado', 'Agregado: $codigo - $nombre');
    } catch (e) {
      AppNotify.error(context, 'Error', 'Error agregando trabajador: $e');
    }
  }

  Future<void> _deleteTrabajador(int id) async {
    await _deleteTrabajadorUseCase.call(id);
    await _load();
  }

  Widget _headerCuadrilla(TaCuadrilla c) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flecha + titulo
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Cuadrilla: ${c.nombre}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.barraNavegacion,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Hora inicio / hora fin
            Row(
              children: [
                Expanded(
                  child: _timeBox(
                    label: "Hora inicio",
                    value: _inicio?.format(context) ?? "--:--",
                    onTap: _pickInicio,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _timeBox(
                    label: "Hora fin",
                    value: _fin?.format(context) ?? "--:--",
                    onTap: _pickFin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.access_time),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _cuadrilla;

    return Scaffold(
      backgroundColor: AppColors.fondoPantalla,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        toolbarHeight:
            0, // 👈 ocultamos AppBar real (cabecera la hacemos nosotros)
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.barraNavegacion,
        onPressed: _scanQrAndAdd,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),

      // ✅ Botón guardar abajo
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.barraNavegacion,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading ? null : _guardarCabecera,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                "Guardar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : c == null
          ? const SizedBox()
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // ✅ Cabecera: cuadrilla + horas
                _headerCuadrilla(c),

                // ✅ Producción KG (solo input)
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _kgCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Producción total (kg) de la cuadrilla",
                        labelStyle: TextStyle(color: AppColors.barraNavegacion),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ✅ Trabajadores
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Trabajadores (QR)",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_trabajadores.isEmpty)
                          const Text(
                            "Aún no hay trabajadores. Usa el botón QR para agregar.",
                          ),
                        for (final t in _trabajadores)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.barraNavegacion
                                  .withOpacity(0.12),
                              child: Icon(
                                Icons.person,
                                color: AppColors.barraNavegacion,
                              ),
                            ),
                            title: Text(
                              "${(t.codigo ?? '').toString().trim()} - ${(t.nombreCompleto ?? '').toString().trim()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _deleteTrabajador(t.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 80), // espacio por el botón abajo
              ],
            ),
    );
  }
}
