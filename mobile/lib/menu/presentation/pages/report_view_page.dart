import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/network/api_client.dart';

import 'package:mobile/features/reports/data/models/report_resumen.dart';
import '../widgets/report_resumen_card.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ReportViewPage extends StatefulWidget {
  const ReportViewPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ReportViewPage> createState() => _ReportViewPageState();
}

class _ReportViewPageState extends State<ReportViewPage> {
  // --------- FILTROS(según rol) ----------

  String?
  _tipoReporte; // APOYO_HORAS | CONTEO_RAPIDO | TRABAJO_AVANCE | SANEAMIENTO
  int? _selectedUserId; // solo ADMIN
  String? _selectedUserRole; // PLANILLERO | SANEAMIENTO (solo ADMIN)

  String? _selectedUserName;

  // --------- FILTROS EXISTENTES ----------
  DateTime? _fecha;
  String _turno = 'Todos'; // 'Todos' | 'Dia' | 'Noche'
  bool _loading = false;

  List<ReportResumen> _reportes = [];

  // ====== AJUSTA ESTOS STRINGS A TUS ROLES REALES ======
  // Si tu backend usa otros valores, cambia aquí solamente.
  static const String roleAdmin = 'ADMINISTRADOR';
  static const String rolePlanillero = 'PLANILLERO';
  static const String roleSaneamiento = 'SANEAMIENTO';

  static const List<String> tiposPlanillero = <String>[
    'APOYO_HORAS',
    'CONTEO_RAPIDO',
    'TRABAJO_AVANCE',
  ];

  Future<List<UserPickerItem>> _fetchUsersForAdminPicker() async {
    final resp = await widget.api.get(
      '/users/pickers?roles=PLANILLERO,SANEAMIENTO',
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba lista de usuarios');
    }

    return decoded
        .map((e) => UserPickerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _limpiar() {
    setState(() {
      _fecha = null;
      _turno = 'Todos';
      _reportes = [];
      // NO limpies el rol/usuario si no quieres, pero normalmente sí:
      _tipoReporte = null;
      _selectedUserId = null;
      _selectedUserRole = null;
    });
  }

  /// Construye query params (fecha/turno/tipo/user_id) y consume GET /reportes
  Future<void> _buscar() async {
    setState(() => _loading = true);

    try {
      final params = <String, String>{};

      if (_fecha != null) {
        params['fecha'] = DateFormat('yyyy-MM-dd').format(_fecha!);
      }
      if (_turno != 'Todos') {
        params['turno'] = _turno; // "Dia" o "Noche"
      }

      // rol real del usuario (igual que en build)
      final auth = AuthControllerScope.of(context);
      final me = auth.user;
      final role = me?.primaryRole ?? 'UNKNOWN';

      // Si ADMIN: permitir user_id (si escogió)
      if (role == roleAdmin) {
        if (_selectedUserId != null)
          params['user_id'] = _selectedUserId.toString();

        if (_selectedUserRole == roleSaneamiento) {
          params['tipo'] = 'SANEAMIENTO';
        } else if (_selectedUserRole == rolePlanillero) {
          params['tipo'] = _tipoReporte ?? tiposPlanillero.first;
        }
      }

      // Si PLANILLERO: tipo obligatorio (3)
      if (role == rolePlanillero) {
        params['tipo'] = _tipoReporte ?? tiposPlanillero.first;
      }

      // Si SANEAMIENTO: tipo fijo
      if (role == roleSaneamiento) {
        params['tipo'] = 'SANEAMIENTO';
      }

      if (_selectedUserId != null) {
        params['user_id'] = _selectedUserId.toString();
      }

      if (_selectedUserRole == roleSaneamiento) {
        // saneamiento siempre SANEAMIENTO
        params['tipo'] = 'SANEAMIENTO';
      } else if (_tipoReporte != null && _tipoReporte!.isNotEmpty) {
        params['tipo'] = _tipoReporte!;
      }

      final path = params.isEmpty
          ? '/reportes'
          : '/reportes?${Uri(queryParameters: params).query}';

      final resp = await widget.api.get(path);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      debugPrint('REPORTES STATUS: ${resp.statusCode}');
      debugPrint('REPORTES BODY: ${resp.body}');

      final decoded = jsonDecode(resp.body);

      // ✅ A) lista directa
      if (decoded is List) {
        final list = decoded
            .map((e) => ReportResumen.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _reportes = list);
        return;
      }

      // ✅ B) wrappers comunes
      if (decoded is Map) {
        if (decoded['items'] is List) {
          final items = decoded['items'] as List;
          final list = items
              .map((e) => ReportResumen.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() => _reportes = list);
          return;
        }
        if (decoded['data'] is List) {
          final items = decoded['data'] as List;
          final list = items
              .map((e) => ReportResumen.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() => _reportes = list);
          return;
        }
      }

      throw Exception('Respuesta inválida (no lista): ${resp.body}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando reportes: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _descargarPdf(int reporteId) async {
    try {
      final resp = await widget.api.getRaw('/reportes/$reporteId/pdf');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      // Guardar en carpeta temporal (no pide permisos)
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/reporte_$reporteId.pdf');
      await file.writeAsBytes(resp.bodyBytes);

      // Abrir
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error descargando PDF: $e')));
    }
  }

  Widget _buildFiltroDinamico(String role) {
    // 1) PLANILLERO: solo selector de tipo (3)
    if (role == rolePlanillero) {
      return _GreenDropdown(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Tipo de reporte',
        value: (_tipoReporte != null && _tipoReporte!.isNotEmpty)
            ? _tipoReporte!
            : tiposPlanillero.first,
        items: tiposPlanillero,
        onChanged: (v) => setState(() => _tipoReporte = v),
      );
    }

    // 2) SANEAMIENTO: fijo
    if (role == roleSaneamiento) {
      // fuerza el tipo internamente
      _tipoReporte = 'SANEAMIENTO';
      return const _GreenLockedBox(
        icon: Icons.cleaning_services_outlined,
        title: 'Tipo de reporte',
        value: 'SANEAMIENTO',
      );
    }

    // 3) ADMIN: selector de usuario + tipo según el usuario
    return Column(
      children: [
        _GreenPickerButton(
          icon: Icons.badge_outlined,
          title: 'Usuario',
          value: _selectedUserId == null
              ? 'Selecciona'
              : (_selectedUserName ?? 'Usuario #$_selectedUserId'),
          onTap: () async {
            // TODO: reemplazar demo por endpoint real
            await _pickUserAdmin();
          },
        ),
        const SizedBox(height: 12),

        if (_selectedUserRole == rolePlanillero)
          _GreenDropdown(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Tipo de reporte',
            value: (_tipoReporte != null && _tipoReporte!.isNotEmpty)
                ? _tipoReporte!
                : tiposPlanillero.first,
            items: tiposPlanillero,
            onChanged: (v) => setState(() => _tipoReporte = v),
          ),

        if (_selectedUserRole == roleSaneamiento)
          const _GreenLockedBox(
            icon: Icons.cleaning_services_outlined,
            title: 'Tipo de reporte',
            value: 'SANEAMIENTO',
          ),

        if (_selectedUserId == null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Selecciona un usuario para filtrar.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  Future<void> _pickUserAdmin() async {
    final auth = AuthControllerScope.of(context);
    debugPrint('MI ROL: ${auth.user?.primaryRole}');
    debugPrint('MI ID: ${auth.user?.id}');
    try {
      final users = await _fetchUsersForAdminPicker();

      final picked = await showModalBottomSheet<UserPickerItem>(
        context: context,
        builder: (_) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = users[i];
                final isPlanillero = u.role == rolePlanillero;

                return ListTile(
                  leading: Icon(
                    isPlanillero
                        ? Icons.badge_outlined
                        : Icons.cleaning_services_outlined,
                  ),
                  title: Text(u.nombre),
                  subtitle: Text(u.role),
                  onTap: () => Navigator.pop(context, u),
                );
              },
            ),
          );
        },
      );

      if (picked == null) return;

      setState(() {
        _selectedUserId = picked.id;
        _selectedUserRole = picked.role;
        _selectedUserName = picked.nombre;

        if (_selectedUserRole == rolePlanillero) {
          _tipoReporte ??= tiposPlanillero.first;
        } else if (_selectedUserRole == roleSaneamiento) {
          _tipoReporte = null; // no aplica
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando usuarios: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerScope.of(context);
    final user = auth.user;
    final role = user?.primaryRole ?? 'UNKNOWN';
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B5A4A),
        foregroundColor: Colors.white,
        title: const Text('Ver reportes'),
      ),
      body: Column(
        children: [
          _FiltrosCard(
            fecha: _fecha,
            turno: _turno,
            onPickFecha: _pickFecha,
            onTurnoChanged: (v) => setState(() => _turno = v),
            onLimpiar: _limpiar,
            onBuscar: _buscar,

            childFiltroDinamico: _buildFiltroDinamico(role),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reportes.isEmpty
                ? const Center(
                    child: Text(
                      'No hay reportes para mostrar.\nUsa los filtros y toca “Buscar”.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _reportes.length,
                    itemBuilder: (_, i) {
                      final r = _reportes[i];
                      return ReportResumenCard(
                        reporte: r,
                        onDownloadPdf: () => _descargarPdf(r.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FiltrosCard extends StatelessWidget {
  const _FiltrosCard({
    required this.fecha,
    required this.turno,
    required this.onPickFecha,
    required this.onTurnoChanged,
    required this.onLimpiar,
    required this.onBuscar,
    required this.childFiltroDinamico,
  });

  final DateTime? fecha;
  final String turno;

  final VoidCallback onPickFecha;
  final ValueChanged<String> onTurnoChanged;

  final VoidCallback onLimpiar;
  final VoidCallback onBuscar;

  final Widget childFiltroDinamico;

  @override
  Widget build(BuildContext context) {
    final fechaTxt = fecha == null
        ? 'Selecciona'
        : DateFormat('dd/MM/yyyy').format(fecha!);

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _GreenPickerButton(
                    icon: Icons.calendar_month_outlined,
                    title: 'Fecha',
                    value: fechaTxt,
                    onTap: onPickFecha,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GreenDropdown(
                    icon: Icons.access_time_rounded,
                    title: 'Turno',
                    value: turno,
                    items: const ['Todos', 'Dia', 'Noche'],
                    onChanged: onTurnoChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ REEMPLAZO del bloque fijo por dinámico
            childFiltroDinamico,

            const SizedBox(height: 10),
            const Text(
              'Se mostrarán únicamente los reportes asociados a tu sesión.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLimpiar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Limpiar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onBuscar,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5A4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserPickerItem {
  final int id;
  final String nombre;
  final String role; // PLANILLERO | SANEAMIENTO

  UserPickerItem({required this.id, required this.nombre, required this.role});

  factory UserPickerItem.fromJson(Map<String, dynamic> json) {
    return UserPickerItem(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] ?? '').toString(),
      role: (json['role'] ?? json['codigo'] ?? '').toString(),
    );
  }
}

class _GreenLockedBox extends StatelessWidget {
  const _GreenLockedBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B5A4A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title\n$value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, color: Colors.white),
        ],
      ),
    );
  }
}

class _GreenPickerButton extends StatelessWidget {
  const _GreenPickerButton({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B5A4A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenDropdown extends StatelessWidget {
  const _GreenDropdown({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B5A4A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0B5A4A),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    items: items
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
