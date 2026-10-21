import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum StatusBadgeTone { ok, warn, violet, mute }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    this.tone = StatusBadgeTone.ok,
  });

  final String text;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusBadgeTone.ok => AppColors.cyan,
      StatusBadgeTone.warn => AppColors.amber,
      StatusBadgeTone.violet => AppColors.violet,
      StatusBadgeTone.mute => AppColors.textMute,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.mono(
          fontSize: 10,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
