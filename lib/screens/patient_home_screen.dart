import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/battery_ring.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/screen_title.dart';
import 'device_ble_scan_screen.dart';
import 'device_history_screen.dart';
import 'device_pause_cursor_screen.dart';
import 'device_settings_screen.dart';
import 'patient_caregivers_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firstName = AuthService.instance.current?.nombres
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle(
                firstName == null || firstName.isEmpty
                    ? 'Hola'
                    : 'Hola, $firstName',
              ),
              const SizedBox(height: 20),
              const _DeviceStatusSection(),
              const SizedBox(height: 18),
              Text(
                'MI CUIDADOR',
                style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              const _CaregiverCard(),
              const SizedBox(height: 12),
              const _ConnectButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: patientBottomNav(PatientTab.inicio),
    );
  }
}

/// Cuidador principal (o el primero) del paciente, con acceso a la lista.
class _CaregiverCard extends StatefulWidget {
  const _CaregiverCard();

  @override
  State<_CaregiverCard> createState() => _CaregiverCardState();
}

class _CaregiverCardState extends State<_CaregiverCard> {
  late final Stream<List<CareAssignment>> _caregivers = CareService.instance
      .watchForPatient(AuthService.instance.currentUid ?? '');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CareAssignment>>(
      stream: _caregivers,
      builder: (context, snapshot) {
        final list = snapshot.data;
        if (list == null || list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.overlay,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              list == null
                  ? (snapshot.hasError
                        ? 'No se pudo cargar tu cuidador.'
                        : 'Cargando…')
                  : 'Todavía no tenés un cuidador asignado. Lo asigna el '
                        'administrador.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textMute,
              ),
            ),
          );
        }
        final main = list.firstWhere(
          (a) => a.responsabilidad == Responsibility.principal,
          orElse: () => list.first,
        );
        final others = list.length - 1;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.overlay,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientCaregiversScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    InitialsAvatar(initialsOf(main.nombreCuidador)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            main.nombreCuidador,
                            style: AppTextStyles.body(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            others > 0
                                ? '${main.relation} · +$others más'
                                : main.relation,
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: AppColors.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textMute,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Batería, conexión, sensor, MAC y última calibración del HeadMouse.
class _DeviceStatusSection extends StatefulWidget {
  const _DeviceStatusSection();

  @override
  State<_DeviceStatusSection> createState() => _DeviceStatusSectionState();
}

class _DeviceStatusSectionState extends State<_DeviceStatusSection> {
  /// Historial guardado en Firestore: la última calibración puede ser de
  /// otro día o de otro teléfono (por ejemplo, la del cuidador).
  late final Stream<List<CalibrationEntry>> _history = DeviceService.instance
      .watchCalibrations(AuthService.instance.currentUid ?? '');
  List<CalibrationEntry>? _latest;
  StreamSubscription<List<CalibrationEntry>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _history.listen(
      (list) => setState(() => _latest = list),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = HeadMouseBle.instance;
    return ListenableBuilder(
      listenable: ble,
      builder: (context, _) {
        final (label, color) = switch (ble.link) {
          HeadMouseLink.connected => ('CONECTADO', AppColors.cyan),
          HeadMouseLink.connecting => ('CONECTANDO…', AppColors.amber),
          HeadMouseLink.disconnected => ('DESCONECTADO', AppColors.textMute),
        };
        final battery = ble.battery;
        final lastCalibration = lastSuccessfulCalibration(_latest);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BatteryRing(
                    batteryLevel: battery == null ? null : battery / 100,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 11,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.overlay,
                border: Border.all(color: AppColors.line, width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                spacing: 9,
                children: [
                  _StatusRow(
                    label: 'Estado del sensor',
                    value: ble.isConnected
                        ? (ble.sensorStatus?.label ?? '—')
                        : '—',
                  ),
                  _StatusRow(label: 'MAC Bluetooth', value: ble.mac ?? '—'),
                  _StatusRow(
                    label: 'Última calibración',
                    value: lastCalibration == null
                        ? 'Sin registro'
                        : _formatTime(lastCalibration),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? 'Hoy, $hh:$mm' : '${t.day}/${t.month}, $hh:$mm';
  }
}

/// Si ya hay conexión va directo a configurar; si no, a buscar.
class _ConnectButton extends StatelessWidget {
  const _ConnectButton();

  @override
  Widget build(BuildContext context) {
    final ble = HeadMouseBle.instance;
    return ListenableBuilder(
      listenable: ble,
      builder: (context, _) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: ble.link == HeadMouseLink.connecting
              ? null
              : () {
                  final Widget next = !ble.isConnected
                      ? const DeviceBleScanScreen()
                      : ble.configMode
                      ? const DeviceSettingsScreen()
                      : const DevicePauseCursorScreen();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => next),
                  );
                },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.line, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            ble.isConnected
                ? 'Configurar dispositivo'
                : 'Conectar y configurar',
            style: AppTextStyles.body(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.mono(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}
