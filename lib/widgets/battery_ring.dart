import 'package:flutter/material.dart';
import 'package:headmouse_pro/theme/app_colors.dart';
import 'package:headmouse_pro/theme/app_text_styles.dart';

class BatteryRing extends StatelessWidget {
  const BatteryRing({super.key, required this.batteryLevel});

  final double batteryLevel;

  @override
  Widget build(BuildContext context) {
    final percent = (batteryLevel * 100).toStringAsFixed(0);
    return Semantics(
      label: 'Batería del dispositivo: $percent por ciento',
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: batteryLevel,
              strokeWidth: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(batteryLevel * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.display(fontSize: 22),
              ),
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
