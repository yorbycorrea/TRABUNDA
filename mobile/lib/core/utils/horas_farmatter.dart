String formatHoras(double horas) {
  if (horas % 1 == 0) {
    return horas.toStringAsFixed(0);
  }

  return horas.toStringAsFixed(1);
}
