import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/core/ui/app_notifications.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key, required this.api, this.pickOnly = true});

  final ApiClient api;
  final bool pickOnly;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _processing = false;
  bool _flashOn = false;
  bool _frontCamera = false;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _lookupTrabajador(String q) async {
    final clean = q.trim().replaceAll(RegExp(r'\s+'), '');
    final url = '/trabajadores/lookup?q=${Uri.encodeQueryComponent(clean)}';

    debugPrint('QR LOOKUP URL: $url');

    final resp = await widget.api.get(url);

    debugPrint('QR LOOKUP STATUS: ${resp.statusCode}');
    debugPrint('QR LOOKUP BODY: ${resp.body}');

    final body = resp.body.trimLeft();
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      throw Exception(
        'Backend devolvió HTML. Revisa baseUrl o ruta /trabajadores/lookup',
      );
    }

    final decoded = jsonDecode(resp.body);

    if (resp.statusCode != 200) {
      final msg = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'Error lookup trabajador (HTTP ${resp.statusCode})';
      throw Exception(msg);
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida: se esperaba un JSON objeto');
    }

    return decoded;
  }

  Future<void> _handleDetection(List<Barcode> barcodes) async {
    if (barcodes.isEmpty || _processing) return;
    debugPrint(
      'QR onDetect: processing=$_processing, barcodes=${barcodes.length}',
    );

    final rawValue = barcodes.first.rawValue?.trim();
    debugPrint('QR scanner >>> [$rawValue]');

    if (rawValue == null || rawValue.isEmpty) return;

    // ✅ Bloquea ANTES del await para que no dispare múltiples requests
    if (mounted) setState(() => _processing = true);

    bool popped = false;

    try {
      final normalizedScannedValue = rawValue.replaceAll(RegExp(r'\s+'), '');
      final data = await _lookupTrabajador(normalizedScannedValue);

      if (!mounted) return;

      final idAny = data['id'];
      final idNum = (idAny is num) ? idAny : num.tryParse(idAny.toString());

      final workerRaw = data['worker'];
      final worker = workerRaw is Map
          ? Map<String, dynamic>.from(workerRaw)
          : null;

      debugPrint('QR worker: $worker');

      final codigo = (worker?['codigo'] ?? data['codigo'] ?? '').toString();
      final dni = (worker?['dni'] ?? data['dni'] ?? '').toString();
      final nombre =
          (worker?['nombre'] ?? data['nombre_completo'] ?? data['nombre'] ?? '')
              .toString();

      debugPrint(
        'QR parsed values -> codigo=$codigo, dni=$dni, nombre_completo=$nombre',
      );

      popped = true;

      // ✅ antes de salir, detén cámara (evita “freeze” al volver)
      await _controller.stop();

      Navigator.pop<Map<String, dynamic>>(context, {
        'id': idNum?.toInt(),
        'codigo': codigo,
        'dni': dni,
        'qOriginal': normalizedScannedValue,
        'scannedValue': normalizedScannedValue,
        'nombre': nombre,
        'nombre_completo': nombre,
        'worker': worker,
      });
    } catch (e) {
      if (!mounted) return;

      AppNotify.error(context, 'Error', 'Error escaneando/lookup: $e');
    } finally {
      // ✅ Si NO salimos de la pantalla, desbloquea overlay
      if (!popped && mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('QR build');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR'),
        actions: [
          IconButton(
            onPressed: () async {
              setState(() => _flashOn = !_flashOn);
              await _controller.toggleTorch();
            },
            icon: Icon(
              Icons.flashlight_on_rounded,
              color: _flashOn ? Colors.green : Colors.grey,
            ),
          ),
          IconButton(
            onPressed: () async {
              setState(() => _frontCamera = !_frontCamera);
              await _controller.switchCamera();
            },
            icon: Icon(
              Icons.camera_front_rounded,
              color: _frontCamera ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Coloca el QR o código de barras dentro del recuadro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      controller: _controller,

                      onDetect: (capture) => _handleDetection(capture.barcodes),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (_processing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
