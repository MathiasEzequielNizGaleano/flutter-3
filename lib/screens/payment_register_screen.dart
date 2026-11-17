import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_card.dart';

/// El administrador registra un pago que recibió (efectivo, transferencia
/// o QR fuera de la app). Queda aprobado y, si es Plan Premium, el plan se
/// extiende un mes. Vuelve con un mensaje.
class PaymentRegisterScreen extends StatefulWidget {
  const PaymentRegisterScreen({
    super.key,
    required this.plan,
    required this.patientName,
    required this.tariffs,
  });

  final PremiumPlan plan;
  final String patientName;
  final Tariffs tariffs;

  @override
  State<PaymentRegisterScreen> createState() => _PaymentRegisterScreenState();
}

class _PaymentRegisterScreenState extends State<PaymentRegisterScreen> {
  final _reference = TextEditingController();
  PaymentConcept _concept = PaymentConcept.premium;
  PaymentMethod _method = PaymentMethod.efectivo;
  bool _saving = false;

  int get _amount => widget.tariffs.amountFor(_concept, widget.plan.segmento);

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payment = await BillingService.instance.registerPayment(
        Charge(
          patientUid: widget.plan.idPaciente,
          patientName: widget.patientName,
          concept: _concept,
          amount: _amount,
          segment: widget.plan.segmento,
        ),
        widget.plan,
        method: _method,
        referencia: _reference.text,
      );
      if (!mounted) return;
      final until = payment.periodoHasta;
      Navigator.pop(
        context,
        until == null
            ? 'Pago registrado. Comprobante ${payment.numero}.'
            : 'Pago registrado. ${widget.patientName} queda Premium hasta el '
                  '${formatLongDate(until)}.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = _concept == PaymentConcept.premium;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Registrar pago',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patientName,
                style: AppTextStyles.display(fontSize: 15),
              ),
              Text(
                widget.plan.segmento.label,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
              const FormSectionLabel('Qué pagó'),
              ChoiceDropdown<PaymentConcept>(
                value: _concept,
                values: PaymentConcept.values,
                hint: 'Concepto',
                icon: Icons.sell_outlined,
                onChanged: (value) {
                  if (value != null) setState(() => _concept = value);
                },
              ),
              ChoiceDropdown<PaymentMethod>(
                value: _method,
                values: PaymentMethod.values,
                hint: 'Cómo pagó',
                icon: Icons.payments_outlined,
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
              AppTextField(
                controller: _reference,
                hint: 'N° de recibo u operación (opcional)',
                icon: Icons.receipt_long,
              ),
              InfoCard(
                rows: [
                  InfoRow('Monto según tarifas', value: formatGs(_amount)),
                  if (premium)
                    InfoRow(
                      'Queda Premium hasta',
                      value: formatLongDate(widget.plan.nextDueAfterPayment()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: _saving ? 'Registrando…' : 'Registrar pago',
                onPressed: _saving ? null : _save,
              ),
              const FormFootnote(
                'El pago queda aprobado a tu nombre y se registra en '
                'Auditoría. El monto sale de la tabla de tarifas.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
