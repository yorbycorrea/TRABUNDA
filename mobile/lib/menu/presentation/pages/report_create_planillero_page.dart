import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/menu/presentation/pages/report_apoyos_horas_page.dart';
import 'package:mobile/features/state_apoyo_horas.dart';
import 'package:mobile/menu/presentation/pages/conteo_rapido_page.dart';
import 'package:mobile/core/theme/app_colors.dart';

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

  bool _loadingApoyo = false;
  String? _errorApoyo;
  int? _apoyoReporteId;

  DateTime _fecha = DateTime.now();
  String _turno = 'Dia';

  String? _tipoReporte;
  bool _creandoReporte = false;

  final TextEditingController _fechaCtrl = TextEditingController();

  final TextEditingController _planilleroCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthControllerScope.read(context);
    final user = auth.user;
    if (user != null) _planilleroCtrl.text = user.nombre;
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
        'turno': _turno,
        'tipo_reporte': tipo,
        'area_id': null,
        'observaciones': null,
      });

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

  Future<void> _openOrGetApoyoHoras() async {
    setState(() {
      _loadingApoyo = true;
      _errorApoyo = null;
    });

    try {
      final f =
          "${_fecha.year.toString().padLeft(4, '0')}-"
          "${_fecha.month.toString().padLeft(2, '0')}-"
          "${_fecha.day.toString().padLeft(2, '0')}";

      final resp = await widget.api.get(
        '/reportes/apoyo-horas/open?turno=${Uri.encodeQueryComponent(_turno)}&fecha=$f',
      );

      final decoded = jsonDecode(resp.body);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          (decoded is Map && decoded['error'] != null)
              ? decoded['error'].toString()
              : 'Error HTTP ${resp.statusCode}',
        );
      }

      final rep = decoded['reporte'];
      final id = (rep['id'] as num).toInt();

      setState(() {
        _apoyoReporteId = id;
        _tipoReporte = 'APOYO_HORAS';
        _reporteIdBackend = id;
      });
    } catch (e) {
      setState(() => _errorApoyo = e.toString());
    } finally {
      setState(() => _loadingApoyo = false);
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
        final reporteId = await _ensureReporteCreado(tipo: 'APOYO_HORAS');
        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApoyosHorasBackendPage(
              api: widget.api,
              reporteId: reporteId,
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
        // Si tu flujo requiere crear/abrir reporte en backend para conteo rápido,
        // descomenta la siguiente línea y pásale reporteId a la página si lo necesitas.
        // final reporteId = await _ensureReporteCreado(tipo: 'CONTEO_RAPIDO');

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConteoRapidoPage(
              api: widget.api,
              // fechaInicial: _fecha,
              // turnoInicial: _turno,
              // si agregas reporteId al constructor, pásalo aquí:
              // reporteId: reporteId,
            ),
          ),
        );
        return; // ✅ IMPORTANTE: evita que caiga en "Tipo no soportado"
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

  // ✅ Paleta oficial (como tu Home)
  static const Color kBluePrimary = Color(0xFF0A7CFF);
  static const Color kBlueSecondary = Color(0xFF4FC3F7);
  static const Color kBg = Color(0xFFF5F7FA);
  static const Color primarySoftBlue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final apoyoExiste = _apoyoReporteId != null;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Crear reporte'),
        elevation: 0,
        backgroundColor: kBluePrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header bonito (solo visual) con la paleta azul
          const _HeaderCompacto(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 1) APOYOS POR HORAS (manteniendo tu lógica exacta)
                _BigActionCard(
                  primary: kBluePrimary,
                  secondary: kBlueSecondary,
                  icon: Icons.access_time_rounded,
                  title: apoyoExiste
                      ? 'Continuar Apoyos por horas'
                      : 'Apoyos por horas',
                  subtitle: _loadingApoyo
                      ? 'Verificando...'
                      : _errorApoyo != null
                      ? 'Error: $_errorApoyo'
                      : apoyoExiste
                      ? 'EN ESPERA • Reporte ID: $_apoyoReporteId'
                      : 'Registrar personal de apoyo por horas',
                  badgeText: apoyoExiste ? 'ABIERTO' : null,
                  loading: _loadingApoyo,
                  onTap: _loadingApoyo
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApoyosHorasHomePage(
                                api: widget.api,
                                turno: _turno, // tu lógica se mantiene
                              ),
                            ),
                          );

                          if (!mounted) return;
                          await _openOrGetApoyoHoras();
                        },
                ),

                const SizedBox(height: 12),

                // 2) TRABAJO POR AVANCE (misma lógica que ya tenías)
                _BigActionCard(
                  primary: kBluePrimary,
                  secondary: kBlueSecondary,
                  icon: Icons.groups_2_rounded,
                  title: 'Trabajo por avance',
                  subtitle: 'Registrar cuadrillas / kilos',
                  loading: _creandoReporte,
                  onTap: _creandoReporte
                      ? null
                      : () => _goToModulo('TRABAJO_AVANCE'),
                ),

                const SizedBox(height: 12),

                // 3) CONTEO RÁPIDO (misma lógica que ya tenías)
                _BigActionCard(
                  primary: kBluePrimary,
                  secondary: kBlueSecondary,
                  icon: Icons.flash_on_rounded,
                  title: 'Conteo rápido',
                  subtitle: 'Registrar conteo rápido de personal',
                  loading: _creandoReporte,
                  onTap: _creandoReporte
                      ? null
                      : () => _goToModulo('CONTEO_RAPIDO'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header simple (bonito) sin campos extra (paleta azul de la app)
class _HeaderCompacto extends StatelessWidget {
  const _HeaderCompacto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.frenchBlue, AppColors.turquoise],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona un módulo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Elige el tipo de reporte que deseas registrar',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta grande bonita (solo UI) con paleta azul
class _BigActionCard extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final bool loading;
  final VoidCallback? onTap;

  const _BigActionCard({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Colors.black12,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.18),
                        secondary.withOpacity(0.18),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: enabled
                                    ? const Color(0xFF1F2937)
                                    : Colors.black38,
                              ),
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: primary.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: enabled
                              ? const Color(0xFF6B7280)
                              : Colors.black26,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled ? Colors.black38 : Colors.black26,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
