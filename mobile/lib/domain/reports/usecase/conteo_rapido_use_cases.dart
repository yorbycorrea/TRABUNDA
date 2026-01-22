import 'package:intl/intl.dart';
import 'package:mobile/domain/reports/models/report_models.dart';

class FormatConteoRapidoDate {
  String call(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}

class BuildConteoRapidoPayload {
  List<ConteoRapidoItem> call(List<ConteoRapidoAreaCantidad> areas) {
    return areas
        .where((area) => area.cantidad > 0)
        .map(
          (area) => ConteoRapidoItem(areaId: area.id, cantidad: area.cantidad),
        )
        .toList();
  }
}

class FormatConteoRapidoSummary {
  String call(List<ConteoRapidoAreaCantidad> areas) {
    final selected = areas.where((area) => area.cantidad > 0).toList();
    if (selected.isEmpty) return 'No hay cantidades ingresadas.';
    selected.sort((a, b) => a.nombre.compareTo(b.nombre));
    return selected.map((a) => '${a.nombre}: ${a.cantidad}').join('\n');
  }
}

class MergeConteoRapidoItems {
  List<ConteoRapidoAreaCantidad> call({
    required List<ConteoRapidoAreaCantidad> areas,
    required List<ConteoRapidoItem> items,
  }) {
    final mapCant = <int, int>{};
    for (final item in items) {
      mapCant[item.areaId] = item.cantidad;
    }

    for (final area in areas) {
      area.cantidad = mapCant[area.id] ?? 0;
    }

    return areas;
  }
}
