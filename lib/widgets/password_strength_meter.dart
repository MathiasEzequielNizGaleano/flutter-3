import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  if (password.length < 8) return score.clamp(0, 1);
  return score;
}

const _labels = AppStrings.strengthLabels;

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  Color _colorFor(int score) => switch (score) {
    <= 1 => AppColors.coral,
    2 => AppColors.amber,
    3 => AppColors.cyan,
    _ => AppColors.isDark ? Colors.greenAccent : const Color(0xFF15803D),
  };

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = passwordStrength(password);
    final color = _colorFor(score);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score ? color : AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          Text.rich(
            TextSpan(
              text: AppStrings.strengthPrefix,
              children: [
                TextSpan(
                  text: _labels[score],
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
          ),
          if (score < 4)
            Text(
              AppStrings.strengthHint,
              style: AppTextStyles.body(
                fontSize: 10.5,
                color: AppColors.textMute,
              ),
            ),
        ],
      ),
    );
  }
}
