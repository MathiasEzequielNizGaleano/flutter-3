import 'package:flutter/material.dart';

import '../services/billing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import 'status_badge.dart';

StatusBadgeTone paymentTone(PaymentStatus status) => switch (status) {
  PaymentStatus.aprobado => StatusBadgeTone.ok,
  PaymentStatus.pendiente => StatusBadgeTone.warn,
  PaymentStatus.rechazado => StatusBadgeTone.mute,
};

/// Un pago de la lista de comprobantes. Se toca para ver el comprobante.
class PaymentTile extends StatelessWidget {
  const PaymentTile({
    super.key,
    required this.payment,
    required this.onTap,
    this.showPatient = false,
  });

  final Payment payment;
  final VoidCallback onTap;

  /// Para el administrador, que ve los pagos de todos.
  final bool showPatient;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final muted = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: glassCardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        p.title,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showPatient && p.nombrePaciente.isNotEmpty)
                        Text('Paciente: ${p.nombrePaciente}', style: muted),
                      Text(
                        [
                          if (p.fecha != null) formatShortDate(p.fecha!),
                          p.metodo.label,
                        ].join(' · '),
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 4,
                  children: [
                    Text(
                      formatGs(p.monto),
                      style: AppTextStyles.mono(
                        fontSize: 12.5,
                        color: AppColors.text,
                      ),
                    ),
                    StatusBadge(
                      text: p.estado.label,
                      tone: paymentTone(p.estado),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
