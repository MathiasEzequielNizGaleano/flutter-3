import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'accessible_tap.dart';

class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          for (final chip in options)
            AccessibleTap(
              onTap: () => onChanged(chip),
              label: 'Filtro: $chip',
              selected: selected == chip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: selected == chip
                      ? AppColors.cyan.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected == chip ? AppColors.cyan : AppColors.line,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chip,
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: selected == chip
                        ? AppColors.text
                        : AppColors.textMute,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
