import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'accessible_tap.dart';

/// Opción que se elige tocándola (método de pago, canal del código). La
/// elegida queda con el borde resaltado.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle = '',
    this.leading,
    this.trailing,
    this.details,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

  /// Contenido extra entre el título y el subtítulo.
  final Widget? details;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AccessibleTap(
      onTap: onTap,
      label: subtitle.isEmpty ? title : '$title. $subtitle',
      selected: selected,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.cyan.withValues(alpha: 0.08)
              : AppColors.overlay,
          border: Border.all(color: selected ? AppColors.cyan : AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ?details,
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.textMute,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}
