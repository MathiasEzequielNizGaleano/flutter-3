import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'accessible_tap.dart';

class OptionGrid extends StatelessWidget {
  const OptionGrid({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        for (final option in options)
          Expanded(
            child: AccessibleTap(
              onTap: () => onChanged(option),
              label: '$label: $option',
              selected: selected == option,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected == option
                      ? AppColors.cyan.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected == option ? AppColors.cyan : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTextStyles.mono(fontSize: 8.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected == option
                            ? AppColors.text
                            : AppColors.textMute,
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
