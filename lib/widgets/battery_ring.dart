import 'package:flutter/material.dart';
import 'package:headmouse_pro/theme/app_colors.dart';
import 'package:headmouse_pro/theme/app_text_styles.dart';

class BatteryRing extends StatelessWidget {
  const BatteryRing({super.key, required this.batteryLevel});

  /// De 0 a 1. Null cuando todavía no se recibió ninguna lectura.
  final double? batteryLevel;

  @override
  Widget build(BuildContext context) {
    final level = batteryLevel;
    final percent = level == null ? '—' : '${(level * 100).round()}%';
    return Semantics(
      label: level == null
          ? 'Batería del dispositivo: sin datos'
          : 'Batería del dispositivo: ${(level * 100).round()} por ciento',
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: level ?? 0,
              strokeWidth: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                level != null && level <= 0.2
                    ? AppColors.coral
                    : AppColors.cyan,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(percent, style: AppTextStyles.display(fontSize: 22)),
              Text(
                'Batería',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
