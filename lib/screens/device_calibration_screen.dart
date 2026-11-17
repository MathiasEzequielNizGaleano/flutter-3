import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_badge.dart';

const _motivos = [
  'Encendido',
  'Recolocación',
  'Se quitó el dispositivo',
  'Diadema desplazada',
  'Cursor descentrado',
  'Solicitud de usuario',
];

/// El firmware mapea ±17000 del acelerómetro a la velocidad máxima.
const _fullScale = 17000.0;

class DeviceCalibrationScreen extends StatefulWidget {
  const DeviceCalibrationScreen({super.key, this.showPatientNav = true});

  final bool showPatientNav;

  @override
  State<DeviceCalibrationScreen> createState() =>
      _DeviceCalibrationScreenState();
}

class _DeviceCalibrationScreenState extends State<DeviceCalibrationScreen> {
  final _ble = HeadMouseBle.instance;
  String _selectedMotivo = 'Recolocación';
  bool _calibrating = false;

  /// Paciente con el que se usa el HeadMouse (null en pruebas sin sesión).
  final DevicePatient? _patient = DeviceService.activePatient;
  bool get _canCalibrate => _patient?.puedeCalibrar ?? true;

  Future<void> _calibrate() async {
    setState(() => _calibrating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final record = await _ble.calibrate(motivo: _selectedMotivo);
      final note = await _record(record);
      final c = record.centro;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Centro calibrado ($_selectedMotivo)'
            '${c == null ? '' : ': AX ${c.ax}, AY ${c.ay}'}$note',
          ),
        ),
      );
    } on HeadMouseException catch (e) {
      // El intento fallido también queda en el historial.
      if (_ble.calibrations.isNotEmpty) await _record(_ble.calibrations.last);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _calibrating = false);
    }
  }

  /// Devuelve un aviso si no se pudo guardar en el historial.
  Future<String> _record(CalibrationRecord record) async {
    final patient = _patient;
    if (patient == null) return '';
    try {
      await DeviceService.instance.recordCalibration(patient, record);
      return '';
    } catch (e) {
      return '. No se pudo guardar en el historial: '
          '${AuthService.describeError(e)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Calibración manual',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListenableBuilder(
            listenable: Listenable.merge([_ble, _ble.telemetry]),
            builder: (context, _) {
              final connected = _ble.isConnected;
              final telemetry = _ble.telemetry.value;
              final status = _ble.sensorStatus;
              final patient = _patient;
              return Column(
                children: [
                  if (patient != null) ...[
                    Text(
                      'Paciente: ${patient.nombre}',
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_canCalibrate) ...[
                    Text(
                      'No tenés permiso para calibrar el HeadMouse de '
                      '${patient?.nombre ?? 'este paciente'}.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  StatusBadge(
                    text: !connected
                        ? 'Sin conexión'
                        : 'MPU6050: ${status?.label ?? '—'}',
                    tone: !connected
                        ? StatusBadgeTone.mute
                        : switch (status) {
                            SensorStatus.ready => StatusBadgeTone.ok,
                            SensorStatus.calibrating => StatusBadgeTone.warn,
                            _ => StatusBadgeTone.mute,
                          },
                  ),
                  const SizedBox(height: 12),
                  _CursorPreview(
                    sample: connected ? telemetry.calibrado : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CenterValue('AX centro', telemetry.centro?.ax),
                      _CenterValue('AY centro', telemetry.centro?.ay),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _calibrating
                        ? 'Mantené la cabeza quieta, mirando al centro de la '
                              'pantalla…'
                        : 'Al calibrar, la posición actual de la cabeza pasa a '
                              'ser el centro del cursor. Tarda unos 2 segundos.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: _calibrating
                          ? AppColors.amber
                          : AppColors.textMute,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MOTIVO',
                      style: AppTextStyles.mono(
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // Alto proporcional al tamaño de texto: con texto grande una
                    // proporción fija recortaría el contenido.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent:
                          64 * MediaQuery.textScalerOf(context).scale(1),
                    ),
                    children: [
                      for (final motivo in _motivos)
                        _MotivoTile(
                          motivo: motivo,
                          selected: _selectedMotivo == motivo,
                          onTap: () => setState(() => _selectedMotivo = motivo),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: _calibrating ? 'Calibrando…' : 'Calibrar centro',
                    onPressed: connected && !_calibrating && _canCalibrate
                        ? _calibrate
                        : null,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _calibrating
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.line, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Volver',
                        style: AppTextStyles.body(color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: widget.showPatientNav
          ? patientBottomNav(PatientTab.dispositivo)
          : null,
    );
  }
}

/// Cruz con un punto que sigue el AX/AY calibrado: en el centro cuando la
/// cabeza está en la posición de calibración.
class _CursorPreview extends StatelessWidget {
  const _CursorPreview({required this.sample});

  final AxisSample? sample;

  @override
  Widget build(BuildContext context) {
    final s = sample;
    final dx = s == null ? 0.0 : (s.ax / _fullScale).clamp(-1.0, 1.0);
    // El firmware mueve el cursor en Y con el mismo signo que AY calibrado.
    final dy = s == null ? 0.0 : (s.ay / _fullScale).clamp(-1.0, 1.0);
    return Semantics(
      label: s == null
          ? 'Vista del cursor sin datos'
          : 'Posición de la cabeza: AX ${s.ax}, AY ${s.ay}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: glassCardDecoration(radius: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 1, color: AppColors.line),
            Container(width: 1, color: AppColors.line),
            AnimatedAlign(
              duration: const Duration(milliseconds: 100),
              alignment: Alignment(dx, dy),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s == null ? AppColors.textMute : AppColors.cyan,
                    boxShadow: s == null
                        ? null
                        : [BoxShadow(color: AppColors.cyan, blurRadius: 10)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterValue extends StatelessWidget {
  const _CenterValue(this.label, this.value);

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
        children: [
          TextSpan(
            text: value?.toString() ?? '—',
            style: AppTextStyles.mono(fontSize: 12, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _MotivoTile extends StatelessWidget {
  const _MotivoTile({
    required this.motivo,
    required this.selected,
    required this.onTap,
  });

  final String motivo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Motivo: $motivo',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.14)
                : AppColors.overlay,
            border: Border.all(
              color: selected ? AppColors.cyan : AppColors.line,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('MOTIVO', style: AppTextStyles.mono(fontSize: 8)),
              const SizedBox(height: 2),
              Text(
                motivo,
                style: AppTextStyles.body(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.text : AppColors.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
