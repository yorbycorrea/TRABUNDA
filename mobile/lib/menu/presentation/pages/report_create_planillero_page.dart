import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/menu/presentation/pages/report_apoyos_horas_page.dart';

class ReportCreatePlanilleroPage extends StatefulWidget {
  const ReportCreatePlanilleroPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReportCreatePlanilleroPage> createState() =>
      _ReportCreatePlanilleroPageState();
}

class _ReportCreatePlanilleroPageState
    extends State<ReportCreatePlanilleroPage> {
  int? _reporteIdBackend;

  DateTime _fecha = DateTime.now();
  String _turno = 'Dia'; // OJO: si en tu BD es enum 'Día' con tilde, usa 'Día'

  String? _tipoReporte;
  bool _creandoReporte = false;

  final TextEditingController _planilleroCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthControllerScope.read(context);
    final user = auth.user;
    if (user != null) _planilleroCtrl.text = user.username;
  }

  @override
  void dispose() {
    _planilleroCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<int> _ensureReporteCreado({required String tipo}) async {
    // Si ya existe, no lo vuelve a crear
    if (_reporteIdBackend != null) {
      return _reporteIdBackend!;
    }

    final auth = AuthControllerScope.read(context);
    if (!auth.isAuthenticated) {
      throw Exception('No autenticado');
    }

    final planillero = _planilleroCtrl.text.trim();
    if (planillero.isEmpty) {
      throw Exception('Planillero vacío');
    }

    final fechaStr = _fecha.toLocal().toString().split(' ').first;

    setState(() => _creandoReporte = true);

    try {
      final resp = await widget.api.post('/reportes', {
        'fecha': fechaStr,
        'turno': _turno, // Debe coincidir EXACTO con enum de BD
        'tipo_reporte': tipo,
        // 👇 IMPORTANTE:
        // Para APOYO_HORAS NO enviamos área aquí
        'area_id': null,
        'observaciones': null,
      });

      debugPrint('POST /reportes status=${resp.statusCode}');
      debugPrint('POST /reportes body=${resp.body}');

      final decoded = jsonDecode(resp.body);

      if (resp.statusCode != 201 && resp.statusCode != 200) {
        final msg = (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'Error creando reporte';
        throw Exception(msg);
      }

      final id = (decoded['reporte_id'] as num).toInt();
      _reporteIdBackend = id;
      return id;
    } finally {
      if (mounted) {
        setState(() => _creandoReporte = false);
      }
    }
  }

  Future<void> _goToModulo(String tipo) async {
    setState(() => _tipoReporte = tipo);

    final auth = AuthControllerScope.read(context);
    if (!auth.isAuthenticated) {
      _toast('No autenticado');
      return;
    }

    final plan = _planilleroCtrl.text.trim();
    if (plan.isEmpty) {
      _toast('Planillero vacío');
      return;
    }
    try {
      if (!mounted) return;

      if (tipo == 'APOYO_HORAS') {
        final reporteId = await _ensureReporteCreado(tipo: 'APOYO_HORAS'); // ✅

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApoyosHorasBackendPage(
              api: widget.api,
              reporteId: reporteId, // ✅ ahora sí existe
              fecha: _fecha,
              turno: _turno,
              planillero: plan,
            ),
          ),
        );
        return;
      }

      if (tipo == 'TRABAJO_AVANCE') {
        _toast('Falta implementar la pantalla de Trabajo por avance');
        return;
      }

      if (tipo == 'CONTEO_RAPIDO') {
        _toast('Falta implementar Conteo rápido');
        return;
      }

      _toast('Tipo no soportado: $tipo');
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _onFinalizarPressed() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Listo'),
        content: const Text(
          'Ya puedes ingresar al módulo y guardar los datos.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear reporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: cs.surfaceVariant.withOpacity(.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2023, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                              initialDate: _fecha,
                            );
                            if (picked != null) setState(() => _fecha = picked);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _fecha.toLocal().toString().split(' ').first,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _turno,
                          items: const [
                            DropdownMenuItem(value: 'Dia', child: Text('Dia')),
                            DropdownMenuItem(
                              value: 'Noche',
                              child: Text('Noche'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Turno',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _creandoReporte
                              ? null
                              : (v) => setState(() => _turno = v ?? 'Dia'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _planilleroCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Planillero',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_tipoReporte != null)
                          Chip(label: Text('Tipo: $_tipoReporte')),
                        if (_reporteIdBackend != null)
                          Chip(label: Text('ID: $_reporteIdBackend')),
                        if (_creandoReporte)
                          const Chip(label: Text('Creando...')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _OptionCard(
            icon: Icons.access_time_rounded,
            title: 'Apoyos por horas',
            subtitle: 'Registrar personal de apoyo por horas',
            onTap: _creandoReporte ? () {} : () => _goToModulo('APOYO_HORAS'),
          ),
          const SizedBox(height: 8),
          _OptionCard(
            icon: Icons.groups_2_rounded,
            title: 'Trabajo por avance',
            subtitle: 'Registrar cuadrillas / kilos',
            onTap: _creandoReporte
                ? () {}
                : () => _goToModulo('TRABAJO_AVANCE'),
          ),
          const SizedBox(height: 8),
          _OptionCard(
            icon: Icons.groups_rounded,
            title: 'Conteo rápido',
            subtitle: 'Registrar conteo rápido de personal',
            onTap: _creandoReporte ? () {} : () => _goToModulo('CONTEO_RAPIDO'),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _onFinalizarPressed,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
