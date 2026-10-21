import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_card.dart';
import '../widgets/profile_parts.dart';
import '../widgets/status_badge.dart';

class _PaymentMethod {
  const _PaymentMethod({
    required this.mark,
    required this.name,
    required this.sub,
    required this.markColors,
    this.details,
    this.badge,
  });

  final String mark;
  final String name;
  final String sub;
  final List<Color> markColors;

  final List<(String, String)>? details;
  final String? badge;
}

final _paymentMethods = [
  _PaymentMethod(
    mark: 'QR',
    name: 'QR Bancard',
    sub: 'Procesado por Pagopar',
    markColors: [AppColors.cyan, AppColors.violet],
    badge: 'Disponible',
  ),
  _PaymentMethod(
    mark: 'TR',
    name: 'Transferencia bancaria',
    sub: 'Envía el comprobante para confirmar el pago.',
    markColors: [AppColors.violet, AppColors.bgPanel2],
    details: [
      ('Cuenta', '6191051808'),
      ('Titular', 'Fernando Adrian Ortiz Sosa'),
      ('Alias', '+595 991 260 736'),
    ],
  ),
  _PaymentMethod(
    mark: 'Gs',
    name: 'Pago en efectivo',
    sub: 'En tienda física',
    markColors: [AppColors.amber, AppColors.coral],
  ),
];

const _invoices = [
  ('Orden #0045 · Pago único', '04 ago 2026 · QR Bancard', 'Gs. 1.550.000'),
  ('Plan Premium · Septiembre', '15 sep 2026 · QR Bancard', 'Gs. 200.000'),
];

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  int _method = 0;

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message (demo, sin backend)')));
  }

  Widget _paymentTile(int index) {
    final method = _paymentMethods[index];
    final selected = _method == index;
    return GestureDetector(
      onTap: () => setState(() => _method = index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
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
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: method.markColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                method.mark,
                style: AppTextStyles.display(fontSize: 11, color: Colors.white),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    method.name,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (method.details != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final (i, (label, value))
                              in method.details!.indexed) ...[
                            if (i > 0) const TextSpan(text: '\n'),
                            TextSpan(text: '$label: '),
                            TextSpan(
                              text: value,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.textMute,
                      ).copyWith(height: 1.5),
                    ),
                  Text(
                    method.sub,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textMute,
                    ),
                  ),
                ],
              ),
            ),
            if (method.badge != null) StatusBadge(text: method.badge!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle('Facturación'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.violet.withValues(alpha: 0.18),
                      AppColors.cyan.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      'HeadMouse Pro · Pago único',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textMute,
                      ),
                    ),
                    Text(
                      'Gs. 1.550.000',
                      style: AppTextStyles.display(fontSize: 24),
                    ),
                    Text(
                      'Incluye dispositivo, app y soporte inicial — sin cuotas',
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: AppColors.textMute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: glassCardDecoration(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 9,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Plan Premium',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const StatusBadge(
                          text: 'Activo',
                          tone: StatusBadgeTone.violet,
                        ),
                      ],
                    ),
                    _row('Monto mensual', 'Gs. 200.000'),
                    _row('Próximo pago', '15 oct 2026'),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'Incluye personalización de la app y soporte técnico '
                        'prioritario. Si no se renueva antes del vencimiento, '
                        'la cuenta vuelve al plan básico.',
                        style: AppTextStyles.body(
                          fontSize: 10.5,
                          color: AppColors.textMute,
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const ProfileSectionTitle('Método de pago'),
              for (var i = 0; i < _paymentMethods.length; i++) _paymentTile(i),
              const ProfileSectionTitle('Comprobante de compra'),
              InfoCard(
                rows: [
                  for (final (title, date, amount) in _invoices)
                    InfoRow(
                      title,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amount,
                            style: AppTextStyles.mono(
                              fontSize: 13,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            date,
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: AppColors.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: _method == 0 ? 'Pagar con QR' : 'Confirmar pago',
                onPressed: () => _showDemoMessage(
                  'Pago con ${_paymentMethods[_method].name}',
                ),
              ),
              const SizedBox(height: 10),
              GhostButton(
                'Descargar comprobante',
                onPressed: () => _showDemoMessage('Descarga de comprobante'),
              ),
              Center(
                child: Text(
                  'Pagos con QR procesados de forma segura por Pagopar',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.textMute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: patientHomeNavItems(),
        currentIndex: 3,
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
      ),
      Text(
        value,
        style: AppTextStyles.mono(fontSize: 13, color: AppColors.text),
      ),
    ],
  );
}
