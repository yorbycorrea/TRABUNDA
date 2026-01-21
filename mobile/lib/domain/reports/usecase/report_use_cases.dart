import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile/domain/reports/models/report_models.dart';
import 'package:mobile/domain/reports/models/report_repository.dart';
import 'package:mobile/features/reports/data/models/report_resumen.dart';

String? _fmtTime(TimeOfDay? t) {
  if (t == null) return null;
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

class FetchUserPickers {
  FetchUserPickers(this._repository);
  final ReportRepository _repository;

  Future<List<UserPickerItem>> call({required List<String> roles}) {
    return _repository.fetchUserPickers(roles: roles);
  }
}

class FetchReportes {
  FetchReportes(this._repository);
  final ReportRepository _repository;

  Future<List<ReportResumen>> call({
    DateTime? fecha,
    String? turno,
    String? tipo,
    int? userId,
  }) {
    return _repository.fetchReportes(
      fecha: fecha,
      turno: turno,
      tipo: tipo,
      userId: userId,
    );
  }
}

class FetchReportePdf {
  FetchReportePdf(this._repository);
  final ReportRepository _repository;

  Future<Uint8List> call(int reporteId) {
    return _repository.fetchReportePdf(reporteId);
  }
}

class FetchConteoRapidoExcel {
  FetchConteoRapidoExcel(this._repository);
  final ReportRepository _repository;

  Future<Uint8List> call(int reporteId) {
    return _repository.fetchConteoRapidoExcel(reporteId);
  }
}

class CreateReport {
  CreateReport(this._repository);
  final ReportRepository _repository;

  Future<int> call({
    required DateTime fecha,
    required String turno,
    required String tipoReporte,
  }) {
    return _repository.createReporte(
      fecha: fecha,
      turno: turno,
      tipoReporte: tipoReporte,
    );
  }
}

class CreateSaneamientoReport {
  CreateSaneamientoReport(this._repository);
  final ReportRepository _repository;

  Future<int> call({required DateTime fecha, required String turno}) {
    return _repository.createReporte(
      fecha: fecha,
      turno: turno,
      tipoReporte: 'SANEAMIENTO',
    );
  }
}

class OpenSaneamientoReport {
  OpenSaneamientoReport(this._repository);
  final ReportRepository _repository;

  Future<ReportOpenInfo> call({
    required DateTime fecha,
    required String turno,
  }) {
    return _repository.openSaneamiento(fecha: fecha, turno: turno);
  }
}

class OpenApoyoHorasReport {
  OpenApoyoHorasReport(this._repository);
  final ReportRepository _repository;

  Future<ReportOpenInfo> call({DateTime? fecha, required String turno}) {
    return _repository.openApoyoHoras(fecha: fecha, turno: turno);
  }
}

class FetchApoyoHorasPendientes {
  FetchApoyoHorasPendientes(this._repository);
  final ReportRepository _repository;

  Future<List<ReportPendiente>> call({
    required int hours,
    DateTime? fecha,
    String? turno,
  }) {
    return _repository.fetchApoyoHorasPendientes(
      hours: hours,
      fecha: fecha,
      turno: turno,
    );
  }
}

class FetchSaneamientoPendientes {
  FetchSaneamientoPendientes(this._repository);
  final ReportRepository _repository;

  Future<List<ReportPendiente>> call({required int hours, String? turno}) {
    return _repository.fetchSaneamientoPendientes(hours: hours, turno: turno);
  }
}

class FetchApoyoAreas {
  FetchApoyoAreas(this._repository);
  final ReportRepository _repository;

  Future<List<ApoyoHorasArea>> call() {
    return _repository.fetchApoyoAreas();
  }
}

class FetchApoyoLineas {
  FetchApoyoLineas(this._repository);
  final ReportRepository _repository;

  Future<List<ApoyoHorasLinea>> call(int reporteId) {
    return _repository.fetchApoyoLineas(reporteId);
  }
}

class UpsertApoyoHorasLinea {
  UpsertApoyoHorasLinea(this._repository);
  final ReportRepository _repository;

  Future<int?> call({
    int? lineaId,
    required int reporteId,
    required int trabajadorId,
    required TimeOfDay inicio,
    TimeOfDay? fin,
    double? horas,
    required int areaId,
  }) {
    return _repository.upsertApoyoLinea(
      lineaId: lineaId,
      reporteId: reporteId,
      trabajadorId: trabajadorId,
      horaInicio: _fmtTime(inicio)!,
      horaFin: _fmtTime(fin),
      horas: horas,
      areaId: areaId,
    );
  }
}

class FetchSaneamientoLineas {
  FetchSaneamientoLineas(this._repository);
  final ReportRepository _repository;

  Future<List<SaneamientoLinea>> call(int reporteId) {
    return _repository.fetchSaneamientoLineas(reporteId);
  }
}

class UpsertSaneamientoLinea {
  UpsertSaneamientoLinea(this._repository);
  final ReportRepository _repository;

  Future<int?> call({
    int? lineaId,
    required int reporteId,
    required int trabajadorId,
    required TimeOfDay inicio,
    TimeOfDay? fin,
    double? horas,
    String? labores,
  }) {
    return _repository.upsertSaneamientoLinea(
      lineaId: lineaId,
      reporteId: reporteId,
      trabajadorId: trabajadorId,
      horaInicio: _fmtTime(inicio)!,
      horaFin: _fmtTime(fin),
      horas: horas,
      labores: labores,
    );
  }
}

class FetchConteoRapidoAreas {
  FetchConteoRapidoAreas(this._repository);
  final ReportRepository _repository;

  Future<List<ConteoRapidoArea>> call() {
    return _repository.fetchConteoRapidoAreas();
  }
}

class OpenConteoRapido {
  OpenConteoRapido(this._repository);
  final ReportRepository _repository;

  Future<ConteoRapidoOpenResult> call({
    required DateTime fecha,
    required String turno,
  }) {
    return _repository.openConteoRapido(fecha: fecha, turno: turno);
  }
}

class SaveConteoRapido {
  SaveConteoRapido(this._repository);
  final ReportRepository _repository;

  Future<int> call({
    required DateTime fecha,
    required String turno,
    required List<ConteoRapidoItem> items,
  }) {
    return _repository.saveConteoRapido(
      fecha: fecha,
      turno: turno,
      items: items,
    );
  }
}

class FetchTrabajoAvance {
  FetchTrabajoAvance(this._repository);
  final ReportRepository _repository;

  Future<TrabajoAvanceResumen> call(int reporteId) {
    return _repository.fetchTrabajoAvanceResumen(reporteId);
  }
}

class StartTrabajoAvance {
  StartTrabajoAvance(this._repository);
  final ReportRepository _repository;

  Future<TrabajoAvanceStartResult> call({
    required DateTime fecha,
    required String turno,
  }) {
    return _repository.startTrabajoAvance(fecha: fecha, turno: turno);
  }
}

class UpdateTrabajoAvanceHorario {
  UpdateTrabajoAvanceHorario(this._repository);
  final ReportRepository _repository;

  Future<void> call({
    required int reporteId,
    TimeOfDay? inicio,
    TimeOfDay? fin,
  }) {
    return _repository.updateTrabajoAvanceHorario(
      reporteId: reporteId,
      horaInicio: _fmtTime(inicio),
      horaFin: _fmtTime(fin),
    );
  }
}

class CreateTrabajoAvanceCuadrilla {
  CreateTrabajoAvanceCuadrilla(this._repository);
  final ReportRepository _repository;

  Future<void> call({
    required int reporteId,
    required String tipo,
    required String nombre,
    int? apoyoDeCuadrillaId,
  }) {
    return _repository.createTrabajoAvanceCuadrilla(
      reporteId: reporteId,
      tipo: tipo,
      nombre: nombre,
      apoyoDeCuadrillaId: apoyoDeCuadrillaId,
    );
  }
}

class FetchTrabajoAvanceCuadrillaDetalle {
  FetchTrabajoAvanceCuadrillaDetalle(this._repository);
  final ReportRepository _repository;

  Future<TrabajoAvanceCuadrillaDetalle> call(int cuadrillaId) {
    return _repository.fetchTrabajoAvanceCuadrillaDetalle(cuadrillaId);
  }
}

class UpdateTrabajoAvanceCuadrilla {
  UpdateTrabajoAvanceCuadrilla(this._repository);
  final ReportRepository _repository;

  Future<void> call({
    required int cuadrillaId,
    TimeOfDay? inicio,
    TimeOfDay? fin,
    required double produccionKg,
  }) {
    return _repository.updateTrabajoAvanceCuadrilla(
      cuadrillaId: cuadrillaId,
      horaInicio: _fmtTime(inicio),
      horaFin: _fmtTime(fin),
      produccionKg: produccionKg,
    );
  }
}

class AddTrabajoAvanceTrabajador {
  AddTrabajoAvanceTrabajador(this._repository);
  final ReportRepository _repository;

  Future<void> call({required int cuadrillaId, required String codigo}) {
    return _repository.addTrabajoAvanceTrabajador(
      cuadrillaId: cuadrillaId,
      codigo: codigo,
    );
  }
}

class DeleteTrabajoAvanceTrabajador {
  DeleteTrabajoAvanceTrabajador(this._repository);
  final ReportRepository _repository;

  Future<void> call(int trabajadorId) {
    return _repository.deleteTrabajoAvanceTrabajador(trabajadorId);
  }
}
