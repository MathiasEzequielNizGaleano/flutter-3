import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';

/// Datos en vivo del HeadMouse conectado. Solo se muestran, no se guardan.
class DeviceLivePanel extends StatelessWidget {
  const DeviceLivePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = HeadMouseBle.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: glassCardDecoration(radius: 14),
      child: ListenableBuilder(
        listenable: Listenable.merge([ble, ble.telemetry]),
        builder: (context, _) {
          final t = ble.telemetry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 7,
            children: [
              Text(
                'EN VIVO',
                style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
              ),
              _LiveRow(
                'Batería',
                ble.battery == null ? '—' : '${ble.battery} %',
              ),
              _LiveRow(
                'MPU6050',
                ble.sensorStatus?.label ?? '—',
                color: switch (ble.sensorStatus) {
                  SensorStatus.error => AppColors.coral,
                  SensorStatus.calibrating => AppColors.amber,
                  _ => null,
                },
              ),
              _LiveRow('MAC BLE', ble.mac ?? '—'),
              _LiveRow('AX / AY originales', _pair(t.raw)),
              _LiveRow('AX / AY calibrados', _pair(t.calibrado)),
            ],
          );
        },
      ),
    );
  }

  static String _pair(AxisSample? s) => s == null ? '—' : '${s.ax} / ${s.ay}';
}

class _LiveRow extends StatelessWidget {
  const _LiveRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.mono(
            fontSize: 12,
            color: color ?? AppColors.text,
          ),
        ),
      ],
    );
  }
}
