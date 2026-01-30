import 'dart:convert';
import 'package:flutter/material.dart';

class AppNotify {
  static const String fallbackMessage =
      'Ocurrió un problema. Intenta nuevamente.';

  static void error(
    BuildContext context, {
    String title = 'Error',
    String message = fallbackMessage,
  }) {
    final cleaned = sanitizeMessage(message, fallback: fallbackMessage);
    final header = title.trim();
    final text = header.isEmpty ? cleaned : '$header: $cleaned';

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  static String friendlyMessage(
    Object? error, {
    String fallback = fallbackMessage,
  }) {
    if (error == null) {
      return fallback;
    }

    if (error is Map && error['message'] != null && error['code'] != null) {
      return sanitizeMessage(error['message'].toString(), fallback: fallback);
    }

    final raw = _stripExceptionPrefix(error.toString());
    final apiMessage = _extractApiMessage(raw);
    if (apiMessage != null) {
      return sanitizeMessage(apiMessage, fallback: fallback);
    }

    return sanitizeMessage(raw, fallback: fallback);
  }

  static String sanitizeMessage(
    String? message, {
    String fallback = fallbackMessage,
  }) {
    if (message == null) {
      return fallback;
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty || _looksTechnical(trimmed)) {
      return fallback;
    }

    return trimmed;
  }

  static String _stripExceptionPrefix(String raw) {
    // Usamos r'' (raw string) para que las barras invertidas no den problemas
    return raw
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .trim();
  }

  static String? _extractApiMessage(String raw) {
    if (!raw.contains('message') || !raw.contains('code')) {
      return null;
    }

    final jsonMatch = RegExp(r'\{.*\}').firstMatch(raw);
    if (jsonMatch != null) {
      final candidate = jsonMatch.group(0);
      if (candidate != null) {
        try {
          final decoded = jsonDecode(candidate);
          if (decoded is Map &&
              decoded['message'] != null &&
              decoded['code'] != null) {
            return decoded['message'].toString();
          }
        } catch (_) {}
      }
    }

    final quoted = RegExp(
      r'message["'
      "'"
      r']?\s*[:=]\s*["'
      "'"
      r']([^"'
      "'"
      r']+)["'
      "'"
      r']',
    );
    final quotedMatch = quoted.firstMatch(raw);
    if (quotedMatch != null) {
      return quotedMatch.group(1);
    }

    final unquoted = RegExp(r'message\s*[:=]\s*([^,}\]]+)');
    final unquotedMatch = unquoted.firstMatch(raw);
    if (unquotedMatch != null) {
      // CORRECCIÓN AQUÍ: Se simplificó el replaceAll para evitar conflictos de comillas
      final value = unquotedMatch.group(1)?.trim() ?? '';
      return value.replaceAll(
        RegExp(
          r"^['"
          r'"]|["'
          r"']$",
        ),
        '',
      );
    }

    return null;
  }

  static bool _looksTechnical(String message) {
    final lower = message.toLowerCase();
    return message.contains('\n') ||
        lower.contains('stacktrace') ||
        lower.contains('stack trace') ||
        lower.contains('exception') ||
        lower.contains('package:') ||
        lower.contains('dart:') ||
        lower.contains(' at ');
  }
}
