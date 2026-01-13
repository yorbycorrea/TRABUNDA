import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mobile/features/reports/data/models/report_resumen.dart';

class ReportResumenCard extends StatelessWidget {
  const ReportResumenCard({
    super.key,
    required this.reporte,
    required this.onDownloadPdf,
    this.onDownloadExcel,
  });

  final ReportResumen reporte;
  final VoidCallback onDownloadPdf;
  final VoidCallback? onDownloadExcel;

  @override
  Widget build(BuildContext context) {
    final fechaTxt = DateFormat('dd/MM/yyyy').format(reporte.fecha);
    final bool isConteo = reporte.tipoReporte == 'CONTEO_RAPIDO';
    final VoidCallback? action = isConteo ? onDownloadExcel : onDownloadPdf;
    debugPrint('isConteo=$isConteo onDownloadExcel=${onDownloadExcel != null}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: fecha + chip turno
            Row(
              children: [
                Text(
                  fechaTxt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B5A4A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    reporte.turno,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reporte.planillero,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 8),
                Text('${reporte.tipoReporte} tipo de reporte'),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),

            const SizedBox(height: 12),
            const Text(
              'Tipos de registro',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (reporte.tipoReporte != null)
                  _TipoChip(label: _nombreTipo(reporte.tipoReporte!)),
              ],
            ),

            const SizedBox(height: 14),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isConteo ? onDownloadExcel : onDownloadPdf,
                icon: const Icon(Icons.download_outlined),
                label: Text(isConteo ? 'Descargar Excel' : 'Descargar reporte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nombreTipo(String t) {
    switch (t) {
      case 'APOYO_HORAS':
        return 'Apoyos por horas';
      case 'TRABAJO_AVANCE':
        return 'Trabajo por avance';
      case 'CONTEO_RAPIDO':
        return 'Conteo rápido';
      case 'SANEAMIENTO':
        return 'Saneamiento';
      default:
        return t;
    }
  }
}

class _TipoChip extends StatelessWidget {
  const _TipoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F3EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB9D8D0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0B5A4A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
