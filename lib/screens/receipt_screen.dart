import 'package:flutter/material.dart';

import '../services/billing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/info_card.dart';
import '../widgets/payment_tile.dart';
import '../widgets/status_badge.dart';

/// Comprobante de un pago (aprobado, pendiente o rechazado).
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (icon, color) = switch (p.estado) {
      PaymentStatus.aprobado => (Icons.check_circle_outline, AppColors.cyan),
      PaymentStatus.pendiente => (Icons.hourglass_top, AppColors.amber),
      PaymentStatus.rechazado => (Icons.cancel_outlined, AppColors.coral),
    };
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text('Comprobante', style: AppTextStyles.display(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 52),
              const SizedBox(height: 8),
              Text(
                formatGs(p.monto),
                style: AppTextStyles.display(fontSize: 26),
              ),
              const SizedBox(height: 6),
              StatusBadge(text: p.estado.label, tone: paymentTone(p.estado)),
              const SizedBox(height: 6),
              Text(
                p.numero.isEmpty ? 'Comprobante' : 'N° ${p.numero}',
                style: AppTextStyles.mono(fontSize: 12, color: AppColors.text),
              ),
              const SizedBox(height: 18),
              InfoCard(
                rows: [
                  InfoRow(
                    'Fecha',
                    value: p.fecha == null ? '—' : formatEventTime(p.fecha!),
                  ),
                  InfoRow('Concepto', value: p.concepto.label),
                  if (p.periodoHasta != null)
                    InfoRow(
                      'Premium hasta',
                      value: formatLongDate(p.periodoHasta!),
                    ),
                  InfoRow(
                    'Paciente',
                    value: p.nombrePaciente.isEmpty ? '—' : p.nombrePaciente,
                  ),
                  if (p.nombrePagador.isNotEmpty)
                    InfoRow('Pagado por', value: p.nombrePagador),
                  InfoRow('Método', value: p.metodo.label),
                  if (p.referencia.isNotEmpty)
                    InfoRow('Referencia', value: p.referencia),
                  InfoRow('Cliente', value: p.segmento.label),
                  if (p.nombreConfirmador.isNotEmpty)
                    InfoRow(
                      p.estado == PaymentStatus.rechazado
                          ? 'Rechazado por'
                          : p.registradoPorAdmin
                          ? 'Registrado por'
                          : 'Confirmado por',
                      value: [
                        p.nombreConfirmador,
                        if (p.fechaConfirmacion != null)
                          formatShortDate(p.fechaConfirmacion!),
                      ].join(' · '),
                    ),
                  if (p.motivoRechazo.isNotEmpty)
                    InfoRow('Motivo', value: p.motivoRechazo, stacked: true),
                ],
              ),
              if (p.pendiente) ...[
                const SizedBox(height: 12),
                Text(
                  p.metodo == PaymentMethod.efectivo
                      ? 'Mostrá este número en la tienda. Cuando pagues, el '
                            'administrador registra el pago.'
                      : 'El administrador confirma el pago cuando ve la '
                            'transferencia.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMute,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Comprobante emitido por la pasarela de pagos simulada de '
                'HeadMouse Pro. No es una factura legal.',
                textAlign: TextAlign.center,
                style: AppTextStyles.mono(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
