// Reportes generales del administrador: pacientes, dispositivos y
// calibraciones. Se calculan en el teléfono a partir de las colecciones que
// el administrador ya puede leer; no se guarda nada.

import 'package:flutter/foundation.dart';

import 'admin_service.dart';
import 'auth_service.dart';
import 'device_service.dart';
import 'records_service.dart';

/// Batería por debajo de este porcentaje se considera baja.
const lowBatteryPercent = 20;

/// Una fila de un reporte: cuántos hay de algo.
@immutable
class Tally {
  const Tally(this.label, this.count);

  final String label;
  final int count;
}

/// Cuenta cuántos pacientes tienen cada valor, en el orden de [values], y
/// agrega "Sin evaluar" al final si hay alguno sin dato.
List<Tally> tallyBy<T extends Choice>(List<T> values, Iterable<T?> data) {
  final list = data.toList();
  final missing = list.where((v) => v == null).length;
  return [
    for (final value in values)
      Tally(value.label, list.where((v) => v == value).length),
    if (missing > 0) Tally('Sin evaluar', missing),
  ];
}

/// Calibraciones de un paciente en el período del reporte.
@immutable
class PatientCalibrations {
  const PatientCalibrations({
    required this.uid,
    required this.name,
    required this.inPeriod,
    required this.failedInPeriod,
    this.last,
  });

  final String uid;
  final String name;
  final int inPeriod;
  final int failedInPeriod;

  /// Última calibración exitosa, de cualquier fecha.
  final DateTime? last;
}

@immutable
class AdminReport {
  const AdminReport({
    required this.activePatients,
    required this.inactivePatients,
    required this.patientsWithDevice,
    required this.assistance,
    required this.cervical,
    required this.headControl,
    required this.devices,
    required this.activeDevices,
    required this.connectedDevices,
    required this.lowBattery,
    required this.unassignedDevices,
    required this.firmware,
    required this.days,
    required this.since,
    required this.calibrations,
    required this.failedCalibrations,
    required this.byPatient,
  });

  /// Arma el reporte. Las calibraciones cuentan si son de los últimos [days]
  /// días contados desde [now].
  factory AdminReport.build({
    required List<ManagedUser> users,
    required Map<String, PatientRecord> records,
    required List<HeadMouseDevice> devices,
    required List<CalibrationEntry> calibrations,
    required int days,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final since = today.subtract(Duration(days: days));
    final patients = [
      for (final u in users)
        if (u.role == UserRole.paciente && u.active) u,
    ];
    final patientIds = {for (final p in patients) p.uid};
    final states = [for (final p in patients) records[p.uid]?.estadoFuncional];
    final withDevice = {
      for (final d in devices)
        if (d.activo && d.idPaciente != null) d.idPaciente!,
    }.intersection(patientIds);

    final firmware = <String, int>{};
    for (final d in devices) {
      final version = d.versionFirmware.trim().isEmpty
          ? 'Sin dato'
          : d.versionFirmware.trim();
      firmware[version] = (firmware[version] ?? 0) + 1;
    }

    final recent = [
      for (final c in calibrations)
        if (c.fecha != null && !c.fecha!.isBefore(since)) c,
    ];
    final byPatient = [
      for (final p in patients)
        PatientCalibrations(
          uid: p.uid,
          name: p.fullName,
          inPeriod: recent.where((c) => c.idPaciente == p.uid).length,
          failedInPeriod: recent
              .where((c) => c.idPaciente == p.uid && !c.exitosa)
              .length,
          last: _lastSuccess(calibrations, p.uid),
        ),
    ]..sort(_needsAttentionFirst);

    return AdminReport(
      activePatients: patients.length,
      inactivePatients: users
          .where((u) => u.role == UserRole.paciente && !u.active)
          .length,
      patientsWithDevice: withDevice.length,
      assistance: tallyBy(Assistance.values, [
        for (final s in states) s?.nivelAsistencia,
      ]),
      cervical: tallyBy(Mobility.values, [
        for (final s in states) s?.movilidadCervical,
      ]),
      headControl: tallyBy(HeadControl.values, [
        for (final s in states) s?.controlCefalico,
      ]),
      devices: devices.length,
      activeDevices: devices.where((d) => d.activo).length,
      connectedDevices: devices.where((d) => d.activo && d.conectado).length,
      lowBattery: devices
          .where(
            (d) =>
                d.activo && d.bateria != null && d.bateria! < lowBatteryPercent,
          )
          .length,
      unassignedDevices: devices
          .where((d) => d.activo && d.idPaciente == null)
          .length,
      firmware: [for (final e in firmware.entries) Tally(e.key, e.value)]
        ..sort((a, b) => b.count.compareTo(a.count)),
      days: days,
      since: since,
      calibrations: recent.length,
      failedCalibrations: recent.where((c) => !c.exitosa).length,
      byPatient: byPatient,
    );
  }

  static DateTime? _lastSuccess(List<CalibrationEntry> all, String uid) {
    DateTime? last;
    for (final c in all) {
      if (c.idPaciente != uid || !c.exitosa || c.fecha == null) continue;
      if (last == null || c.fecha!.isAfter(last)) last = c.fecha;
    }
    return last;
  }

  /// Primero quien nunca se calibró, después la calibración más vieja.
  static int _needsAttentionFirst(
    PatientCalibrations a,
    PatientCalibrations b,
  ) {
    final la = a.last, lb = b.last;
    if (la == null || lb == null) {
      if (la == lb) return a.name.compareTo(b.name);
      return la == null ? -1 : 1;
    }
    return la.compareTo(lb);
  }

  // Pacientes
  final int activePatients;
  final int inactivePatients;
  final int patientsWithDevice;
  final List<Tally> assistance;
  final List<Tally> cervical;
  final List<Tally> headControl;

  // Dispositivos
  final int devices;
  final int activeDevices;
  final int connectedDevices;
  final int lowBattery;
  final int unassignedDevices;
  final List<Tally> firmware;

  // Calibraciones del período
  final int days;

  /// Comienzo del período.
  final DateTime since;
  final int calibrations;
  final int failedCalibrations;
  final List<PatientCalibrations> byPatient;

  int get successfulCalibrations => calibrations - failedCalibrations;

  /// Pacientes activos sin una calibración exitosa en el período.
  int get uncalibratedPatients =>
      byPatient.where((p) => p.last == null || p.last!.isBefore(since)).length;
}
