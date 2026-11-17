import 'dart:async';

import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/records_service.dart';
import '../services/reports.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/filter_chips.dart';
import '../widgets/profile_parts.dart';
import '../widgets/state_views.dart';

const _periods = {'7 días': 7, '30 días': 30, '90 días': 90};

/// Reportes generales de pacientes, dispositivos y calibraciones (solo
/// administradores). Se actualizan solos.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  List<ManagedUser>? _users;
  Map<String, PatientRecord>? _records;
  List<HeadMouseDevice>? _devices;
  List<CalibrationEntry>? _calibrations;
  Object? _error;
  String _period = '30 días';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  void _listen() {
    _cancel();
    void onError(Object e) {
      if (mounted) setState(() => _error = e);
    }

    _subs
      ..add(
        AdminService.instance.watchUsers().listen(
          (v) => setState(() => _users = v),
          onError: onError,
        ),
      )
      ..add(
        RecordsService.instance.watchAllPatients().listen(
          (v) => setState(() => _records = v),
          onError: onError,
        ),
      )
      ..add(
        DeviceService.instance.watchDevices().listen(
          (v) => setState(() => _devices = v),
          onError: onError,
        ),
      )
      ..add(
        DeviceService.instance.watchAllCalibrations().listen(
          (v) => setState(() => _calibrations = v),
          onError: onError,
        ),
      );
  }

  void _retry() {
    setState(() => _error = null);
    _listen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Reportes', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return ErrorView(
        onRetry: _retry,
        message: AuthService.describeError(error),
      );
    }
    final users = _users;
    final records = _records;
    final devices = _devices;
    final calibrations = _calibrations;
    if (users == null ||
        records == null ||
        devices == null ||
        calibrations == null) {
      return const LoadingView();
    }
    final r = AdminReport.build(
      users: users,
      records: records,
      devices: devices,
      calibrations: calibrations,
      days: _periods[_period]!,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Datos al ${formatEventTime(DateTime.now())}. Se actualizan solos.',
            style: AppTextStyles.body(
              fontSize: 11.5,
              color: AppColors.textMute,
            ),
          ),
          const ProfileSectionTitle('Pacientes'),
          _StatRow([
            ('Activos', r.activePatients),
            ('Con HeadMouse', r.patientsWithDevice),
            ('De baja', r.inactivePatients),
          ]),
          _MeterList(
            title: 'Nivel de asistencia',
            rows: r.assistance,
            total: r.activePatients,
            unit: 'pacientes',
          ),
          _MeterList(
            title: 'Movilidad cervical',
            rows: r.cervical,
            total: r.activePatients,
            unit: 'pacientes',
          ),
          _MeterList(
            title: 'Control cefálico',
            rows: r.headControl,
            total: r.activePatients,
            unit: 'pacientes',
          ),
          const ProfileSectionTitle('Dispositivos'),
          _StatRow([
            ('Activos', r.activeDevices),
            ('Conectados', r.connectedDevices),
            ('Sin asignar', r.unassignedDevices),
          ]),
          const SizedBox(height: 10),
          _StatRow([
            ('Batería baja', r.lowBattery),
            ('Inactivos', r.devices - r.activeDevices),
            ('Registrados', r.devices),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Batería baja: menos de $lowBatteryPercent % en la última '
              'conexión. "Conectados" es el último estado que informó la app.',
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.textMute,
              ),
            ),
          ),
          _MeterList(
            title: 'Versión de firmware',
            rows: r.firmware,
            total: r.devices,
            unit: 'equipos',
          ),
          const ProfileSectionTitle('Calibraciones'),
          FilterChips(
            options: _periods.keys.toList(),
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 12),
          _StatRow([
            ('Calibraciones', r.calibrations),
            ('Exitosas', r.successfulCalibrations),
            ('Con error', r.failedCalibrations),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              r.activePatients == 0
                  ? 'No hay pacientes activos.'
                  : switch (r.uncalibratedPatients) {
                      0 =>
                        'Todos los pacientes tienen una calibración exitosa '
                            'en los últimos ${r.days} días.',
                      1 =>
                        '1 paciente sin una calibración exitosa en los '
                            'últimos ${r.days} días.',
                      final n =>
                        '$n pacientes sin una calibración exitosa en los '
                            'últimos ${r.days} días.',
                    },
              style: AppTextStyles.body(fontSize: 12, color: AppColors.text),
            ),
          ),
          for (final p in r.byPatient)
            _PatientCalibrationRow(p, since: r.since),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.stats);

  final List<(String, int)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: Semantics(
              label: '$label: $value',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: glassCardDecoration(radius: 14),
                child: Column(
                  children: [
                    Text('$value', style: AppTextStyles.display(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 10.5,
                        color: AppColors.textMute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Una lista de proporciones: nombre, barra y cifra por fila, todas sobre el
/// mismo total. Un solo color; el riel es el mismo color más claro.
class _MeterList extends StatelessWidget {
  const _MeterList({
    required this.title,
    required this.rows,
    required this.total,
    required this.unit,
  });

  final String title;
  final List<Tally> rows;
  final int total;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Sin $unit registrados.',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
            )
          else
            for (final row in rows) _MeterRow(row, total: total, unit: unit),
        ],
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow(this.row, {required this.total, required this.unit});

  final Tally row;
  final int total;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : row.count / total;
    final percent = (share * 100).round();
    return Semantics(
      label: '${row.label}: ${row.count} de $total $unit, $percent por ciento',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 5,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: AppTextStyles.body(fontSize: 12),
                  ),
                ),
                Text(
                  '${row.count} · $percent %',
                  style: AppTextStyles.mono(
                    fontSize: 11,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: AppColors.cyan.withValues(alpha: 0.14)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: share.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un paciente en el reporte de calibraciones. Se resalta si no tiene una
/// calibración exitosa en el período.
class _PatientCalibrationRow extends StatelessWidget {
  const _PatientCalibrationRow(this.p, {required this.since});

  final PatientCalibrations p;
  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final last = p.last;
    final stale = last == null || last.isBefore(since);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: stale
            ? AppColors.amber.withValues(alpha: 0.06)
            : AppColors.overlay,
        border: Border.all(
          color: stale
              ? AppColors.amber.withValues(alpha: 0.4)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(
            stale ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 18,
            color: stale ? AppColors.amber : AppColors.cyan,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  p.name,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  last == null
                      ? 'Nunca se calibró con éxito'
                      : 'Última exitosa: ${formatLongDate(last)}',
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.textMute,
                  ),
                ),
              ],
            ),
          ),
          Text(
            p.failedInPeriod == 0
                ? '${p.inPeriod} en el período'
                : '${p.inPeriod} · ${p.failedInPeriod} con error',
            textAlign: TextAlign.right,
            style: AppTextStyles.mono(fontSize: 10.5, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
