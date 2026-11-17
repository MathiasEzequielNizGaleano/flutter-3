import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'profile_parts.dart';

/// Botón con borde de color: coral para acciones que quitan algo
/// (baja, quitar acceso) y cian para las que lo devuelven.
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.cyan;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

ShapeBorder appDialogShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16),
  side: BorderSide(color: AppColors.line),
);

/// Pide confirmación. Devuelve `true` solo si la persona confirma.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.bgPanel,
      shape: appDialogShape(),
      title: Text(
        title,
        style: AppTextStyles.display(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        message,
        style: AppTextStyles.body(
          fontSize: 11.5,
          color: AppColors.textMute,
        ).copyWith(height: 1.5),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlineActionButton(
            label: confirmLabel,
            danger: danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        GhostButton('Cancelar', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
  return confirmed ?? false;
}
