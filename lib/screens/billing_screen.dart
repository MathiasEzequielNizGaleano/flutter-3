import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/care_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/filter_chips.dart';
import '../widgets/gradient_button.dart';
import '../widgets/payment_tile.dart';
import '../widgets/profile_parts.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'checkout_screen.dart';
import 'receipt_screen.dart';

/// Plan Premium, pago del dispositivo y comprobantes de un paciente. El
/// cuidador elige de cuál de sus pacientes.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, this.caregiverNav = false});

  /// Muestra la barra del cuidador (y sus pacientes) en lugar de la del
  /// paciente.
  final bool caregiverNav;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final String _uid = AuthService.instance.currentUid ?? '';
  late Stream<List<CareAssignment>> _links = _watchLinks();
  String? _selected;

  Stream<List<CareAssignment>> _watchLinks() =>
      CareService.instance.watchForCaregiver(_uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: widget.caregiverNav
            ? _caregiverBody()
            : _PatientBilling(
                key: ValueKey(_uid),
                patientUid: _uid,
                patientName: AuthService.instance.current?.fullName ?? '',
              ),
      ),
      bottomNavigationBar: widget.caregiverNav
          ? AppBottomNav(items: caregiverNavItems(), currentIndex: 3)
          : patientBottomNav(PatientTab.facturacion),
    );
  }

  Widget _caregiverBody() => StreamBuilder<List<CareAssignment>>(
    stream: _links,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorView(
          onRetry: () => setState(() => _links = _watchLinks()),
          message: AuthService.describeError(snapshot.error!),
        );
      }
      if (!snapshot.hasData) return const LoadingView();
      // Un paciente por chip, aunque haya más de un vínculo con él.
      final links = {
        for (final l in snapshot.data!) l.idPaciente: l,
      }.values.toList();
      if (links.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyState(
            title: 'Sin pacientes a cargo',
            message:
                'Cuando tengas un paciente asignado vas a poder pagar su '
                'Plan Premium y su HeadMouse desde acá.',
            icon: Icons.receipt_long,
          ),
        );
      }
      final link = links.firstWhere(
        (l) => l.idPaciente == _selected,
        orElse: () => links.first,
      );
      return _PatientBilling(
        key: ValueKey(link.idPaciente),
        patientUid: link.idPaciente,
        patientName: link.nombrePaciente,
        header: links.length < 2
            ? Text(
                'Paciente: ${link.nombrePaciente}',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textMute,
                ),
              )
            : FilterChips(
                options: [for (final l in links) l.nombrePaciente],
                selected: link.nombrePaciente,
                onChanged: (name) => setState(
                  () => _selected = links
                      .firstWhere((l) => l.nombrePaciente == name)
                      .idPaciente,
                ),
              ),
      );
    },
  );
}

class _PatientBilling extends StatefulWidget {
  const _PatientBilling({
    super.key,
    required this.patientUid,
    required this.patientName,
    this.header,
  });

  final String patientUid;
  final String patientName;
  final Widget? header;

  @override
  State<_PatientBilling> createState() => _PatientBillingState();
}

class _PatientBillingState extends State<_PatientBilling> {
  late Stream<PremiumPlan> _plan;
  late Stream<List<Payment>> _payments;
  late Stream<Tariffs> _tariffs;

  BillingService get _service => BillingService.instance;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _plan = _service.watchPlan(
      widget.patientUid,
      patientName: widget.patientName,
    );
    _payments = _service.watchPayments(widget.patientUid);
    _tariffs = _service.watchTariffs();
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pay(
    PremiumPlan plan,
    PaymentConcept concept,
    int amount,
  ) async {
    final payment = await Navigator.push<Payment>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          plan: plan,
          charge: Charge(
            patientUid: plan.idPaciente,
            patientName: plan.nombrePaciente.isEmpty
                ? widget.patientName
                : plan.nombrePaciente,
            concept: concept,
            amount: amount,
            segment: plan.segmento,
          ),
        ),
      ),
    );
    if (payment == null || !mounted) return;
    _show(switch (payment.estado) {
      PaymentStatus.aprobado => 'Pago aprobado. Comprobante ${payment.numero}.',
      PaymentStatus.pendiente =>
        'Pago informado. Queda pendiente hasta que lo confirme el '
            'administrador.',
      PaymentStatus.rechazado => 'El pago fue rechazado. No se cobró nada.',
    });
  }

  Future<void> _setRenewal(PremiumPlan plan, bool cancel) async {
    if (cancel) {
      final until = plan.proximoPago;
      final confirmed = await confirmAction(
        context,
        title: '¿Cancelar la renovación?',
        message:
            'El Plan Premium no se va a renovar.'
            '${until == null ? '' : ' Seguís con Premium hasta el ${formatLongDate(until)}; después pasás al plan básico.'}',
        confirmLabel: 'Cancelar renovación',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await _service.setRenewal(plan, cancelado: cancel);
      _show(
        cancel
            ? 'Listo. El Plan Premium no se va a renovar.'
            : 'Listo. El Plan Premium se renueva de nuevo.',
      );
    } on AuthException catch (e) {
      _show(e.message);
    }
  }

  void _open(Payment payment) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReceiptScreen(payment: payment)),
  );

  @override
  Widget build(BuildContext context) {
    Widget error(Object e) => ErrorView(
      onRetry: () => setState(_watch),
      message: AuthService.describeError(e),
    );
    return StreamBuilder<Tariffs>(
      stream: _tariffs,
      builder: (context, tariffs) => StreamBuilder<PremiumPlan>(
        stream: _plan,
        builder: (context, plan) => StreamBuilder<List<Payment>>(
          stream: _payments,
          builder: (context, payments) {
            final failure = tariffs.error ?? plan.error ?? payments.error;
            if (failure != null) return error(failure);
            if (!tariffs.hasData || !plan.hasData || !payments.hasData) {
              return const LoadingView();
            }
            return _content(tariffs.data!, plan.data!, payments.data!);
          },
        ),
      ),
    );
  }

  Widget _content(Tariffs tariffs, PremiumPlan plan, List<Payment> payments) {
    Payment? find(PaymentConcept concept, PaymentStatus status) {
      for (final p in payments) {
        if (p.concepto == concept && p.estado == status) return p;
      }
      return null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Facturación'),
          if (widget.header != null) ...[
            const SizedBox(height: 10),
            widget.header!,
          ],
          const SizedBox(height: 16),
          _PlanCard(
            plan: plan,
            monthly: tariffs.amountFor(PaymentConcept.premium, plan.segmento),
            pending: find(PaymentConcept.premium, PaymentStatus.pendiente),
            onPay: (amount) => _pay(plan, PaymentConcept.premium, amount),
            onRenewal: (cancel) => _setRenewal(plan, cancel),
          ),
          const SizedBox(height: 12),
          _DeviceCard(
            price: tariffs.amountFor(PaymentConcept.dispositivo, plan.segmento),
            paid: find(PaymentConcept.dispositivo, PaymentStatus.aprobado),
            pending: find(PaymentConcept.dispositivo, PaymentStatus.pendiente),
            onPay: (amount) => _pay(plan, PaymentConcept.dispositivo, amount),
            onOpen: _open,
          ),
          const ProfileSectionTitle('Comprobantes'),
          if (payments.isEmpty)
            Text(
              'Todavía no hay pagos registrados.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textMute,
              ),
            ),
          for (final p in payments)
            PaymentTile(payment: p, onTap: () => _open(p)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Pasarela de pagos simulada (Pagopar · QR Bancard): no se '
              'cobra dinero real.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 10.5,
                color: AppColors.textMute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _row(String label, String value, {Color? color}) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  spacing: 12,
  children: [
    Flexible(
      child: Text(
        label,
        style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
      ),
    ),
    Text(
      value,
      style: AppTextStyles.mono(fontSize: 13, color: color ?? AppColors.text),
    ),
  ],
);

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.monthly,
    required this.pending,
    required this.onPay,
    required this.onRenewal,
  });

  final PremiumPlan plan;
  final int monthly;
  final Payment? pending;
  final ValueChanged<int> onPay;

  /// `true` para cancelar la renovación, `false` para reanudarla.
  final ValueChanged<bool> onRenewal;

  @override
  Widget build(BuildContext context) {
    final status = plan.status;
    final due = plan.proximoPago;
    final waiting = pending;
    final muted = AppTextStyles.body(
      fontSize: 10.5,
      color: AppColors.textMute,
    ).copyWith(height: 1.5);
    return Container(
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
        spacing: 9,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  'Plan Premium',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(
                text: switch (status) {
                  PlanStatus.premium => 'Activo',
                  PlanStatus.vencido => 'Vencido',
                  PlanStatus.sinPlan => 'Sin plan',
                },
                tone: switch (status) {
                  PlanStatus.premium => StatusBadgeTone.violet,
                  PlanStatus.vencido => StatusBadgeTone.warn,
                  PlanStatus.sinPlan => StatusBadgeTone.mute,
                },
              ),
            ],
          ),
          _row('Monto mensual', formatGs(monthly)),
          if (status == PlanStatus.premium && due != null)
            _row(
              plan.cancelado ? 'Activo hasta' : 'Próximo pago',
              formatLongDate(due),
            ),
          if (status == PlanStatus.vencido && due != null)
            _row('Venció el', formatLongDate(due), color: AppColors.amber),
          Text('INCLUYE', style: AppTextStyles.mono(fontSize: 9.5)),
          for (final (title, detail) in premiumFeatures)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(Icons.check, size: 16, color: AppColors.cyan),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '$title. ',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: detail,
                          style: TextStyle(
                            color: AppColors.textMute,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    style: AppTextStyles.body(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          if (status == PlanStatus.vencido)
            Text(
              'Venció el pago: las funciones Premium están deshabilitadas '
              'hasta que se pague.',
              style: muted.copyWith(color: AppColors.amber),
            )
          else if (status == PlanStatus.premium && plan.cancelado)
            Text(
              'No se va a renovar. Después del vencimiento la cuenta vuelve '
              'al plan básico.',
              style: muted,
            ),
          if (waiting != null)
            Text(
              'Pago pendiente de confirmación: ${waiting.metodo.label} · '
              '${formatGs(waiting.monto)}. El administrador lo confirma.',
              style: muted.copyWith(color: AppColors.amber),
            )
          else ...[
            const SizedBox(height: 2),
            switch (status) {
              PlanStatus.sinPlan => GradientButton(
                label: 'Activar Plan Premium',
                onPressed: () => onPay(monthly),
              ),
              PlanStatus.vencido => GradientButton(
                label: 'Pagar y reactivar',
                onPressed: () => onPay(monthly),
              ),
              PlanStatus.premium => GhostButton(
                'Pagar el próximo mes',
                onPressed: () => onPay(monthly),
              ),
            },
          ],
          if (status == PlanStatus.premium)
            Center(
              child: TextButton(
                onPressed: () => onRenewal(!plan.cancelado),
                child: Text(
                  plan.cancelado
                      ? 'Reanudar la renovación'
                      : 'Cancelar la renovación',
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: plan.cancelado ? AppColors.cyan : AppColors.coral,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.price,
    required this.paid,
    required this.pending,
    required this.onPay,
    required this.onOpen,
  });

  final int price;
  final Payment? paid;
  final Payment? pending;
  final ValueChanged<int> onPay;
  final ValueChanged<Payment> onOpen;

  @override
  Widget build(BuildContext context) {
    final done = paid;
    final waiting = pending;
    final muted = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  'HeadMouse Pro · Pago único',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (done != null)
                const StatusBadge(text: 'Pagado')
              else if (waiting != null)
                const StatusBadge(
                  text: 'Pendiente',
                  tone: StatusBadgeTone.warn,
                ),
            ],
          ),
          _row('Precio', formatGs(done?.monto ?? price)),
          if (done != null) ...[
            Text(
              [
                if (done.fecha != null)
                  'Pagado el ${formatLongDate(done.fecha!)}',
                done.metodo.label,
              ].join(' · '),
              style: muted,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onOpen(done),
                child: Text(
                  'Ver comprobante',
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ),
          ] else if (waiting != null)
            Text(
              'Esperando que el administrador confirme el pago '
              '(${waiting.metodo.label}).',
              style: muted,
            )
          else ...[
            Text(
              'Incluye dispositivo, app y soporte inicial, sin cuotas.',
              style: muted,
            ),
            GhostButton('Pagar el dispositivo', onPressed: () => onPay(price)),
          ],
        ],
      ),
    );
  }
}
