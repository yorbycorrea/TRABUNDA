import 'package:flutter/material.dart';
import 'app_notifications.dart';

void showSavedToast(
  BuildContext context, {
  String message = 'Guardado correctamente',
}) {
  final normalized = message.toLowerCase();
  if (normalized.contains('error')) {
    AppNotify.error(context, 'Error', message);
  } else {
    AppNotify.success(context, 'Guardado', message);
  }
}
