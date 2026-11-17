import 'dart:math';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../utils/validators.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/profile_parts.dart';
import '../widgets/selectable_tile.dart';
import '../widgets/status_badge.dart';
import 'receipt_screen.dart';

/// Cuenta para las transferencias (la misma que figuraba en el diseño).
const _bankDetails = [
  ('Cuenta', '6191051808'),
  ('Titular', 'Fernando Adrian Ortiz Sosa'),
  ('Alias', '+595 991 260 736'),
];

/// Pagar un cargo con la pasarela simulada. Vuelve con el [Payment] creado
/// (o `null` si se fue sin pagar).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.charge, required this.plan});

  final Charge charge;
  final PremiumPlan plan;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.qr;
  bool _showQr = false;
  bool _busy = false;
  Payment? _result;

  /// Orden de la pasarela, para dibujar el QR.
  final _order = Random().nextInt(1 << 31);

  BillingService get _service => BillingService.instance;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Payment> Function() action) async {
    setState(() => _busy = true);
    try {
      final payment = await action();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = payment;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _payQr(bool approved) => _run(
    () => _service.payWithQr(widget.charge, widget.plan, approved: approved),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _run(
      () => _service.submitPayment(
        widget.charge,
        method: _method,
        referencia: _reference.text,
      ),
    );
  }

  void _retry() => setState(() {
    _result = null;
    _showQr = false;
  });

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return PopScope(
      canPop: result == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, result);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text('Pagar', style: AppTextStyles.display(fontSize: 18)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: result == null
                ? _form()
                : _ResultView(
                    payment: result,
                    onRetry: _retry,
                    onDone: () => Navigator.pop(context, result),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final charge = widget.charge;
    final premium = charge.concept == PaymentConcept.premium;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Summary(
            title: charge.concept.label,
            patient: charge.patientName,
            amount: charge.amount,
            note: premium
                ? 'Queda pago hasta el '
                      '${formatLongDate(widget.plan.nextDueAfterPayment())}.'
                : 'Incluye dispositivo, app y soporte inicial, sin cuotas.',
          ),
          const ProfileSectionTitle('Método de pago'),
          for (final method in PaymentMethod.values)
            SelectableTile(
              title: method.label,
              subtitle: switch (method) {
                PaymentMethod.qr => 'Procesado por Pagopar · al instante',
                PaymentMethod.transferencia =>
                  'Enviá el número de operación para confirmar el pago.',
                PaymentMethod.efectivo => 'En la tienda física',
              },
              selected: _method == method,
              onTap: _busy
                  ? () {}
                  : () => setState(() {
                      _method = method;
                      _showQr = false;
                    }),
              leading: _MethodMark(method),
              trailing: method == PaymentMethod.qr
                  ? const StatusBadge(text: 'Al instante')
                  : null,
              details: method == PaymentMethod.transferencia
                  ? _BankDetails()
                  : null,
            ),
          const SizedBox(height: 6),
          ...switch (_method) {
            PaymentMethod.qr when _showQr => [
              _QrPanel(
                order: _order,
                amount: charge.amount,
                busy: _busy,
                onApprove: () => _payQr(true),
                onReject: () => _payQr(false),
              ),
            ],
            PaymentMethod.qr => [
              GradientButton(
                label: 'Pagar con QR',
                onPressed: () => setState(() => _showQr = true),
              ),
            ],
            PaymentMethod.transferencia => [
              AppTextField(
                controller: _reference,
                hint: 'N° de operación de la transferencia',
                icon: Icons.receipt_long,
                keyboardType: TextInputType.number,
                validator: (v) => Validators.required(
                  v,
                  'Escribí el número de operación que te dio el banco.',
                ),
              ),
              GradientButton(
                label: _busy ? 'Enviando…' : 'Enviar comprobante',
                onPressed: _busy ? null : _submit,
              ),
            ],
            PaymentMethod.efectivo => [
              Text(
                'Generá la orden y mostrá el número en la tienda. Cuando '
                'pagues, el administrador registra el pago y el comprobante '
                'aparece en Facturación.',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: _busy ? 'Generando…' : 'Generar orden de pago',
                onPressed: _busy ? null : _submit,
              ),
            ],
          },
          const SizedBox(height: 16),
          Text(
            'Pasarela de pagos simulada: no se cobra dinero real. Con el plan '
            'gratuito de Firebase no se puede conectar Pagopar ni Bancard.',
            textAlign: TextAlign.center,
            style: AppTextStyles.mono(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.title,
    required this.patient,
    required this.amount,
    required this.note,
  });

  final String title;
  final String patient;
  final int amount;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
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
          title,
          style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
        ),
        Text(formatGs(amount), style: AppTextStyles.display(fontSize: 24)),
        if (patient.isNotEmpty)
          Text('Paciente: $patient', style: AppTextStyles.body(fontSize: 12)),
        Text(
          note,
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.textMute),
        ),
      ],
    ),
  );
}

class _MethodMark extends StatelessWidget {
  const _MethodMark(this.method);

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (mark, colors) = switch (method) {
      PaymentMethod.qr => ('QR', [AppColors.cyan, AppColors.violet]),
      PaymentMethod.transferencia => (
        'TR',
        [AppColors.violet, AppColors.bgPanel2],
      ),
      PaymentMethod.efectivo => ('Gs', [AppColors.amber, AppColors.coral]),
    };
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        mark,
        style: AppTextStyles.display(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

class _BankDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final (i, (label, value)) in _bankDetails.indexed) ...[
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
  );
}

/// El QR de la orden y los botones para simular la respuesta del banco.
class _QrPanel extends StatelessWidget {
  const _QrPanel({
    required this.order,
    required this.amount,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final int order;
  final int amount;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.overlay,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      spacing: 10,
      children: [
        Text(
          'Escaneá el código con la app de tu banco',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Semantics(
            image: true,
            label: 'Código QR de pago simulado',
            child: CustomPaint(
              size: const Size.square(170),
              painter: _FakeQrPainter(order),
            ),
          ),
        ),
        Text(
          'Pagopar · ${formatGs(amount)}',
          style: AppTextStyles.mono(fontSize: 11, color: AppColors.text),
        ),
        const StatusBadge(text: 'Simulado', tone: StatusBadgeTone.mute),
        Text(
          'Como no hay un banco real del otro lado, elegí qué responde:',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.textMute),
        ),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            label: busy ? 'Procesando…' : 'Simular pago aprobado',
            onPressed: busy ? null : onApprove,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : onReject,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.coral.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Simular pago rechazado',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.coral),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Dibuja algo con aspecto de QR (no se puede leer: es una simulación).
class _FakeQrPainter extends CustomPainter {
  _FakeQrPainter(this.seed);

  final int seed;
  static const _cells = 25;

  bool _finder(int x, int y) {
    for (final (fx, fy) in const [(0, 0), (_cells - 7, 0), (0, _cells - 7)]) {
      final dx = x - fx, dy = y - fy;
      if (dx < 0 || dy < 0 || dx > 6 || dy > 6) continue;
      final ring = max((dx - 3).abs(), (dy - 3).abs());
      return ring != 2;
    }
    return false;
  }

  bool _nearFinder(int x, int y) =>
      (x < 8 && y < 8) ||
      (x >= _cells - 8 && y < 8) ||
      (x < 8 && y >= _cells - 8);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _cells;
    final paint = Paint()..color = Colors.black;
    final random = Random(seed);
    for (var y = 0; y < _cells; y++) {
      for (var x = 0; x < _cells; x++) {
        final on = _nearFinder(x, y) ? _finder(x, y) : random.nextBool();
        if (on) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FakeQrPainter old) => old.seed != seed;
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.payment,
    required this.onRetry,
    required this.onDone,
  });

  final Payment payment;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (icon, color, title, message) = switch (p.estado) {
      PaymentStatus.aprobado => (
        Icons.check_circle_outline,
        AppColors.cyan,
        '¡Pago aprobado!',
        p.periodoHasta != null
            ? 'El Plan Premium de ${p.nombrePaciente} queda activo hasta el '
                  '${formatLongDate(p.periodoHasta!)}.'
            : 'El pago de ${p.concepto.label} quedó registrado.',
      ),
      PaymentStatus.pendiente when p.metodo == PaymentMethod.efectivo => (
        Icons.storefront_outlined,
        AppColors.amber,
        'Orden de pago generada',
        'Mostrá el número ${p.numero} en la tienda. Cuando pagues, el '
            'administrador registra el pago.',
      ),
      PaymentStatus.pendiente => (
        Icons.hourglass_top,
        AppColors.amber,
        'Comprobante enviado',
        'El administrador confirma el pago cuando ve la transferencia. El '
            'estado se actualiza solo en Facturación.',
      ),
      PaymentStatus.rechazado => (
        Icons.cancel_outlined,
        AppColors.coral,
        'Pago rechazado',
        'El banco rechazó el pago (simulado). No se cobró nada; podés '
            'intentar de nuevo.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(icon, color: color, size: 64),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.display(fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 13, color: AppColors.textMute),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatGs(p.monto)} · N° ${p.numero}',
          textAlign: TextAlign.center,
          style: AppTextStyles.mono(fontSize: 11, color: AppColors.text),
        ),
        const SizedBox(height: 24),
        if (p.estado == PaymentStatus.rechazado)
          GradientButton(label: 'Intentar de nuevo', onPressed: onRetry)
        else
          GradientButton(
            label: 'Ver comprobante',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReceiptScreen(payment: p)),
            ),
          ),
        const SizedBox(height: 10),
        GhostButton('Volver a Facturación', onPressed: onDone),
      ],
    );
  }
}
