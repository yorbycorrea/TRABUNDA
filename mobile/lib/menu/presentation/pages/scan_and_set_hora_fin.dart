import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/ui/app_notifications.dart';
import 'package:mobile/core/widgets/qr_scanner.dart';

typedef HoraFinSetCallback =
    void Function(TimeOfDay fin, {String? scannedValue});

typedef ConfirmReplaceHoraFinCallback =
    Future<bool> Function(BuildContext context);

Future<void> scanAndSetHoraFin({
  required BuildContext context,
  required ApiClient api,
  required String codigoTrabajadorBloque,
  required TimeOfDay? horaFinActual,
  required HoraFinSetCallback onHoraFinSet,
  ConfirmReplaceHoraFinCallback? onConfirmReplace,
}) async {
  final codigoBloque = _normalize(codigoTrabajadorBloque, padLength: 5);

  if (codigoBloque.isEmpty) {
    AppNotify.warning(
      context,
      'Atención',
      'Primero debe registrar el trabajador antes de marcar hora fin.',
    );
    return;
  }

  if (horaFinActual != null) {
    final shouldReplace =
        await (onConfirmReplace?.call(context) ??
            _showDefaultReplaceDialog(context));
    if (!shouldReplace) return;
  }

  final result = await Navigator.push<Map<String, dynamic>?>(
    context,
    MaterialPageRoute(builder: (_) => QrScannerPage(api: api)),
  );

  if (result == null) return;

  final workerRaw = result['worker'];
  final worker = workerRaw is Map<String, dynamic>
      ? workerRaw
      : (workerRaw is Map ? Map<String, dynamic>.from(workerRaw) : null);

  final scannedValue = _normalize(
    result['scannedValue'] ??
        result['qOriginal'] ??
        result['codigo'] ??
        result['dni'] ??
        '',
  );
  final scannedCodigo = _normalize(
    result['codigo'] ?? worker?['codigo'] ?? '',
    padLength: 5,
  );

  if (scannedCodigo.isEmpty || scannedCodigo != codigoBloque) {
    AppNotify.error(
      context,
      'Error',
      'El fotocheck escaneado no corresponde a este trabajador.',
    );
    return;
  }

  final now = DateTime.now();
  final fin = TimeOfDay(hour: now.hour, minute: now.minute);

  onHoraFinSet(fin, scannedValue: scannedValue.isEmpty ? null : scannedValue);

  AppNotify.success(context, 'Éxito', 'Hora fin registrada correctamente.');
}

String _normalize(dynamic value, {int? padLength}) {
  final raw = (value ?? '').toString().trim().replaceAll(RegExp(r'\s+'), '');
  if (raw.isEmpty) return raw;
  if (padLength != null && RegExp(r'^\d+$').hasMatch(raw)) {
    return raw.padLeft(padLength, '0');
  }
  return raw;
}

Future<bool> _showDefaultReplaceDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmar reescaneo'),
      content: const Text(
        'La hora fin ya está registrada. ¿Desea volver a escanear?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Reescanear'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
