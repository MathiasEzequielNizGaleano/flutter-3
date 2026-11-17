import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';

/// Un evento de auditoría o de acceso. Los fallidos se resaltan.
class AuditEventCard extends StatelessWidget {
  const AuditEventCard(this.entry, {super.key, this.showActor = true});

  final AuditEvent entry;

  /// En el historial de una sola cuenta el nombre sobra: arriba va la
  /// acción.
  final bool showActor;

  Widget _pair(String left, String right, TextStyle leftStyle) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Flexible(child: Text(left, style: leftStyle)),
      Flexible(
        child: Text(
          right,
          textAlign: TextAlign.right,
          style: AppTextStyles.mono(fontSize: 10, color: AppColors.textMute),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final meta = AppTextStyles.body(fontSize: 10.5, color: AppColors.textMute);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: entry.failed
            ? AppColors.amber.withValues(alpha: 0.06)
            : AppColors.overlay,
        border: Border.all(
          color: entry.failed
              ? AppColors.amber.withValues(alpha: 0.4)
              : AppColors.line,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          _pair(
            showActor ? entry.actor : entry.action,
            formatEventTime(entry.time),
            AppTextStyles.body(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (showActor)
            Text(
              entry.action,
              style: AppTextStyles.body(fontSize: 12, color: AppColors.text),
            ),
          if (entry.metaLeft.isNotEmpty || entry.metaRight.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Flexible(child: Text(entry.metaLeft, style: meta)),
                Flexible(
                  child: Text(
                    entry.metaRight,
                    textAlign: TextAlign.right,
                    style: meta,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
