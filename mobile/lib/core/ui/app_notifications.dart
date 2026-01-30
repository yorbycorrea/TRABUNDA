import 'dart:async';
import 'package:flutter/material.dart';

enum _AppNotifyType { success, error, warning, info }

class AppNotify {
  static const Duration _defaultDuration = Duration(seconds: 5);
  static OverlayEntry? _currentEntry;
  static GlobalKey<_AppNotifyBannerState>? _currentKey;
  static Timer? _dismissTimer;

  static void success(BuildContext context, String title, String message) {
    _show(
      context,
      type: _AppNotifyType.success,
      title: title,
      message: message,
    );
  }

  static void error(BuildContext context, String title, String message) {
    _show(
      context,
      type: _AppNotifyType.error,
      title: title,
      message: message,
      duration: const Duration(seconds: 6),
    );
  }

  static void warning(BuildContext context, String title, String message) {
    _show(
      context,
      type: _AppNotifyType.warning,
      title: title,
      message: message,
    );
  }

  static void info(BuildContext context, String title, String message) {
    _show(context, type: _AppNotifyType.info, title: title, message: message);
  }

  static void _show(
    BuildContext context, {
    required _AppNotifyType type,
    required String title,
    required String message,
    Duration? duration,
  }) {
    _removeCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);
    // Nota: Si 'overlay' nunca es nulo según tu configuración,
    // puedes quitar esta validación para evitar el warning amarillo.
    if (overlay == null) return;

    final key = GlobalKey<_AppNotifyBannerState>();

    // SOLUCIÓN AL ERROR DE REFERENCIA: Declaramos primero y asignamos después.
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AppNotifyBanner(
        key: key,
        type: type,
        title: title,
        message: message,
        onDismissed: () =>
            _removeIfCurrent(entry), // Ahora 'entry' es accesible
      ),
    );

    _currentEntry = entry;
    _currentKey = key;
    overlay.insert(entry);

    final effectiveDuration = duration ?? _defaultDuration;
    if (effectiveDuration > Duration.zero) {
      _dismissTimer = Timer(effectiveDuration, () {
        _currentKey?.currentState?.dismiss();
      });
    }
  }

  static void _removeCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentKey = null;

    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }

  static void _removeIfCurrent(OverlayEntry entry) {
    if (_currentEntry != entry) {
      return;
    }
    _removeCurrent();
  }
}

class _AppNotifyBanner extends StatefulWidget {
  const _AppNotifyBanner({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.onDismissed,
  });

  final _AppNotifyType type;
  final String title;
  final String message;
  final VoidCallback onDismissed;

  @override
  State<_AppNotifyBanner> createState() => _AppNotifyBannerState();
}

class _AppNotifyBannerState extends State<_AppNotifyBanner> {
  static const Duration _animationDuration = Duration(milliseconds: 250);
  bool _visible = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    if (mounted) {
      setState(() {
        _visible = false;
      });
      Future.delayed(_animationDuration, widget.onDismissed);
    } else {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AppNotifyPalette.fromType(widget.type);
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSlide(
          duration: _animationDuration,
          offset: _visible ? Offset.zero : const Offset(0, -0.2),
          child: AnimatedOpacity(
            duration: _animationDuration,
            opacity: _visible ? 1 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    // CORRECCIÓN DE DEPRECACIÓN: withOpacity -> withValues
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(palette.icon, color: palette.border, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.text),
                      tooltip: 'Cerrar',
                      onPressed: dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppNotifyPalette {
  const _AppNotifyPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color text;
  final IconData icon;

  static _AppNotifyPalette fromType(_AppNotifyType type) {
    switch (type) {
      case _AppNotifyType.success:
        return _AppNotifyPalette(
          background: const Color(0xFFE8F5E9),
          border: const Color(0xFF2E7D32),
          text: const Color(0xFF1B5E20),
          icon: Icons.check_circle,
        );
      case _AppNotifyType.error:
        return _AppNotifyPalette(
          background: const Color(0xFFFFEBEE),
          border: const Color(0xFFC62828),
          text: const Color(0xFFB71C1C),
          icon: Icons.error,
        );
      case _AppNotifyType.warning:
        return _AppNotifyPalette(
          background: const Color(0xFFFFF8E1),
          border: const Color(0xFFF9A825),
          text: const Color(0xFFF57F17),
          icon: Icons.warning_amber,
        );
      case _AppNotifyType.info:
        return _AppNotifyPalette(
          background: const Color(0xFFE3F2FD),
          border: const Color(0xFF1976D2),
          text: const Color(0xFF0D47A1),
          icon: Icons.info,
        );
    }
  }
}
