import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
// Importación necesaria para el Scope

class HomeMenuPage extends StatelessWidget {
  const HomeMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerScope.of(context);
    final user = auth.user;

    final nombre = user?.nombre ?? '';
    final role = user?.primaryRole ?? 'UNKNOWN';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A7CFF), Color(0xFF4FC3F7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon/logo.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PROCESOS MARINOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ), // Cierre correcto de Positioned
              ], // Cierre correcto de children de Stack
            ),
            const SizedBox(height: 40),
            // == CONTENIDO CENTRAL ======
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (user != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hola, $nombre',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text(
                            role,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          avatar: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _OptionCard(
                      icon: Icons.analytics_outlined,
                      title: 'Ver reportes',
                      description: 'Consulta y analiza los datos de produccion',
                      onTap: () {
                        Navigator.pushNamed(context, '/reports/list');
                      },
                    ),
                    const SizedBox(height: 20),

                    _OptionCard(
                      icon: Icons.note_add_outlined,
                      title: 'Ingresar informacion',
                      description: 'Registra informacion',
                      onTap: () {
                        Navigator.pushNamed(context, '/reports/create');
                      },
                    ),
                    const Spacer(),

                    TextButton.icon(
                      onPressed: () async {
                        // Logout (limpia token y user)
                        await AuthControllerScope.read(context).logout();

                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.grey),
                      label: const Text(
                        'Cerrar Sesion',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====Widget para las tarjetas
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          children: [
            Icon(icon, size: 50, color: Colors.blueAccent),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
