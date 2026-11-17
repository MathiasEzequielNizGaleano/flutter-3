import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/filter_chips.dart';
import '../widgets/gradient_button.dart';
import '../widgets/payment_tile.dart';
import '../widgets/profile_parts.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'payment_register_screen.dart';
import 'receipt_screen.dart';

const _planFilters = ['Todos', 'Premium', 'Sin plan', 'Vencidos', 'B2C', 'B2B'];

/// Un paciente con su plan y sus equipos.
class _PlanRow {
  const _PlanRow(this.user, this.plan, this.devices);

  final ManagedUser user;
  final PremiumPlan plan;
  final List<HeadMouseDevice> devices;
}

/// Plan Premium de cada paciente, pagos por confirmar y tarifas.
class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  List<ManagedUser>? _users;
  Map<String, PremiumPlan>? _plans;
  List<Payment>? _payments;
  List<HeadMouseDevice>? _devices;

  /// Tarifas guardadas en Firestore.
  Tariffs? _tariffs;
  Object? _error;
  String _filter = _planFilters.first;
  bool _savingTariffs = false;
  final _tariffControllers = {
    for (final t in Tariff.values) t: TextEditingController(),
  };

  BillingService get _billing => BillingService.instance;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    for (final controller in _tariffControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _subscribe() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _error = null;
    void fail(Object e) {
      if (mounted) setState(() => _error = e);
    }

    _subs.addAll([
      AdminService.instance.watchUsers().listen(
        (v) => setState(() => _users = v),
        onError: fail,
      ),
      _billing.watchPlans().listen(
        (v) => setState(() => _plans = {for (final p in v) p.idPaciente: p}),
        onError: fail,
      ),
      _billing.watchAllPayments().listen(
        (v) => setState(() => _payments = v),
        onError: fail,
      ),
      DeviceService.instance.watchDevices().listen(
        (v) => setState(() => _devices = v),
        onError: fail,
      ),
      _billing.watchTariffs().listen(_onTariffs, onError: fail),
    ]);
  }

  void _onTariffs(Tariffs tariffs) {
    // Lo que está escribiendo el administrador no se pisa.
    final editing = _tariffs != null && _tariffsChanged;
    setState(() => _tariffs = tariffs);
    if (editing) return;
    for (final MapEntry(key: tariff, value: controller)
        in _tariffControllers.entries) {
      controller.text = formatAmount(tariffs.of(tariff));
    }
  }

  bool get _tariffsChanged {
    final saved = _tariffs;
    if (saved == null) return false;
    return _tariffControllers.entries.any(
      (e) => parseGs(e.value.text) != saved.of(e.key),
    );
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _show(done);
    } on AuthException catch (e) {
      if (mounted) _show(e.message);
    }
  }

  List<_PlanRow> get _rows {
    final plans = _plans!;
    return [
      for (final u in _users!)
        if (u.role == UserRole.paciente && u.active)
          _PlanRow(
            u,
            (plans[u.uid] ?? PremiumPlan(idPaciente: u.uid)).withName(
              u.fullName,
            ),
            [
              for (final d in _devices!)
                if (d.idPaciente == u.uid) d,
            ],
          ),
    ]..sort((a, b) => a.user.fullName.compareTo(b.user.fullName));
  }

  bool _matches(_PlanRow row) => switch (_filter) {
    'Premium' => row.plan.status == PlanStatus.premium,
    'Sin plan' => row.plan.status == PlanStatus.sinPlan,
    'Vencidos' => row.plan.status == PlanStatus.vencido,
    'B2C' => row.plan.segmento == Segment.b2c,
    'B2B' => row.plan.segmento == Segment.b2b,
    _ => true,
  };

  Future<void> _onAction(_PlanRow row, String action) async {
    final plan = row.plan;
    final name = row.user.fullName;
    switch (action) {
      case 'Dar de baja':
        final confirmed = await confirmAction(
          context,
          title: '¿Dar de baja el Plan Premium?',
          message:
              '$name pierde las funciones Premium ahora mismo. Los pagos '
              'anteriores quedan registrados.',
          confirmLabel: 'Dar de baja',
        );
        if (!confirmed) return;
        await _act(
          () => _billing.endPlan(plan),
          'Plan Premium de $name dado de baja.',
        );
      case 'Pasar a B2B' || 'Pasar a B2C':
        final segment = plan.segmento == Segment.b2c
            ? Segment.b2b
            : Segment.b2c;
        final confirmed = await confirmAction(
          context,
          title: '¿$action?',
          message:
              'A partir de ahora a $name se le cobran las tarifas de '
              '${segment.label}.',
          confirmLabel: action,
          danger: false,
        );
        if (!confirmed) return;
        await _act(
          () => _billing.setSegment(plan, segment),
          '$name ahora es ${segment.label}.',
        );
      default:
        final tariffs = _tariffs;
        if (tariffs == null || !mounted) return;
        final message = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentRegisterScreen(
              plan: plan,
              patientName: name,
              tariffs: tariffs,
            ),
          ),
        );
        if (message != null && mounted) _show(message);
    }
  }

  Future<void> _confirm(Payment p) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Confirmar el pago?',
      message:
          '${p.concepto.label} de ${p.nombrePaciente}\n'
          '${formatGs(p.monto)} · ${p.metodo.label}'
          '${p.referencia.isEmpty ? '' : '\nReferencia: ${p.referencia}'}\n\n'
          'Confirmalo solo si ya recibiste la plata.',
      confirmLabel: 'Confirmar pago',
      danger: false,
    );
    if (!confirmed) return;
    final plan =
        (_plans?[p.idPaciente] ?? PremiumPlan(idPaciente: p.idPaciente))
            .withName(p.nombrePaciente);
    await _act(
      () => _billing.confirmPayment(p, plan),
      'Pago de ${p.nombrePaciente} confirmado.',
    );
  }

  Future<void> _reject(Payment p) async {
    final reason = await _askReason(context);
    if (reason == null) return;
    await _act(
      () => _billing.rejectPayment(p, reason),
      'Pago de ${p.nombrePaciente} rechazado.',
    );
  }

  void _open(Payment p) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReceiptScreen(payment: p)),
  );

  Future<void> _saveTariffs() async {
    final before = _tariffs;
    if (before == null) return;
    var after = before;
    for (final MapEntry(key: tariff, value: controller)
        in _tariffControllers.entries) {
      final amount = parseGs(controller.text);
      if (amount == null) {
        _show('Revisá "${tariff.label}": tiene que ser un monto mayor que 0.');
        return;
      }
      after = after.copyWith(tariff, amount);
    }
    setState(() => _savingTariffs = true);
    await _act(() => _billing.saveTariffs(before, after), 'Tarifas guardadas.');
    if (mounted) setState(() => _savingTariffs = false);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: () => _tariffsChanged,
      listenable: Listenable.merge(_tariffControllers.values.toList()),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.text,
          title: Text(
            'Planes y pagos',
            style: AppTextStyles.display(fontSize: 18),
          ),
        ),
        body: SafeArea(child: _body()),
        bottomNavigationBar: AppBottomNav(
          items: adminNavItems(),
          currentIndex: 0,
        ),
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return ErrorView(
        onRetry: () => setState(_subscribe),
        message: AuthService.describeError(error),
      );
    }
    if (_users == null ||
        _plans == null ||
        _payments == null ||
        _devices == null ||
        _tariffs == null) {
      return const LoadingView();
    }
    final tariffs = _tariffs!;
    final rows = _rows;
    final shown = rows.where(_matches).toList();
    final pending = _payments!.where((p) => p.pendiente).toList();
    int count(PlanStatus s) => rows.where((r) => r.plan.status == s).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _StatCard(
                  num: '${count(PlanStatus.premium)}',
                  label: 'Premium',
                ),
              ),
              Expanded(
                child: _StatCard(
                  num: '${count(PlanStatus.sinPlan)}',
                  label: 'Sin plan',
                ),
              ),
              Expanded(
                child: _StatCard(
                  num: '${count(PlanStatus.vencido)}',
                  label: 'Vencidos',
                  numColor: AppColors.amber,
                ),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            ProfileSectionTitle('Pagos por confirmar (${pending.length})'),
            for (final p in pending)
              _PendingCard(
                payment: p,
                onConfirm: () => _confirm(p),
                onReject: () => _reject(p),
                onOpen: () => _open(p),
              ),
          ],
          const ProfileSectionTitle('Pacientes'),
          FilterChips(
            options: _planFilters,
            selected: _filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                rows.isEmpty
                    ? 'Todavía no hay pacientes activos.'
                    : 'Ningún paciente con este filtro.',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
            ),
          for (final row in shown)
            _PlanCard(
              row: row,
              tariffs: tariffs,
              onAction: (action) => _onAction(row, action),
            ),
          Text(
            'La fecha de pago es la que ven el paciente y su cuidador en '
            'Facturación como “Próximo pago”. Al registrar o confirmar un '
            'pago, la fecha avanza un mes.',
            style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
          ),
          if (_payments!.isNotEmpty) ...[
            const ProfileSectionTitle('Últimos pagos'),
            for (final p in _payments!.take(8))
              PaymentTile(payment: p, showPatient: true, onTap: () => _open(p)),
          ],
          const SizedBox(height: 18),
          Text(
            'TARIFAS Y MONTOS A COBRAR',
            style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          for (final tariff in Tariff.values)
            _TariffField(
              tariff: tariff,
              controller: _tariffControllers[tariff]!,
            ),
          Text(
            'Los nuevos montos se aplican a los próximos cobros. Cada cambio '
            'queda registrado en Auditoría con el usuario, la fecha y el '
            'valor anterior.',
            style: AppTextStyles.body(fontSize: 11, color: AppColors.textMute),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: Listenable.merge(_tariffControllers.values.toList()),
            builder: (context, _) => GradientButton(
              label: _savingTariffs ? 'Guardando…' : 'Guardar tarifas',
              onPressed: _tariffsChanged && !_savingTariffs
                  ? _saveTariffs
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Pide el motivo para rechazar un pago. `null` si se cancela.
Future<String?> _askReason(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _ReasonDialog());

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  // Es del diálogo: así sigue vivo mientras se cierra con la animación.
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.bgPanel,
    shape: appDialogShape(),
    title: Text(
      '¿Rechazar el pago?',
      style: AppTextStyles.display(fontSize: 14.5, fontWeight: FontWeight.w600),
    ),
    content: TextField(
      controller: _reason,
      autofocus: true,
      maxLines: 2,
      style: AppTextStyles.body(fontSize: 13),
      decoration: appFieldDecoration(
        hintText: 'Motivo (por ejemplo: no llegó la transferencia)',
      ),
    ),
    actionsOverflowDirection: VerticalDirection.down,
    actions: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlineActionButton(
          label: 'Rechazar pago',
          danger: true,
          onPressed: () {
            final text = _reason.text.trim();
            Navigator.pop(context, text.isEmpty ? 'Sin motivo indicado' : text);
          },
        ),
      ),
      GhostButton('Cancelar', onPressed: () => Navigator.pop(context)),
    ],
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.payment,
    required this.onConfirm,
    required this.onReject,
    required this.onOpen,
  });

  final Payment payment;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final muted = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  '${p.concepto.label} · ${p.nombrePaciente}',
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatGs(p.monto),
                style: AppTextStyles.mono(
                  fontSize: 12.5,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          Text(
            [
              p.metodo.label,
              if (p.referencia.isNotEmpty) 'Ref. ${p.referencia}',
              if (p.fecha != null) formatEventTime(p.fecha!),
            ].join(' · '),
            style: muted,
          ),
          if (p.nombrePagador.isNotEmpty)
            Text('Informado por ${p.nombrePagador}', style: muted),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton('Confirmar pago', onPressed: onConfirm),
              _ActionButton('Rechazar', onPressed: onReject, danger: true),
              TextButton(
                onPressed: onOpen,
                child: Text(
                  'Ver',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
    this.label, {
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.cyan;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: danger ? color.withValues(alpha: 0.6) : color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: AppTextStyles.body(fontSize: 12, color: color)),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.row,
    required this.tariffs,
    required this.onAction,
  });

  final _PlanRow row;
  final Tariffs tariffs;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final plan = row.plan;
    final status = plan.status;
    final due = plan.proximoPago;
    final late = status == PlanStatus.vencido;
    final muted = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);
    final monthly = tariffs.amountFor(PaymentConcept.premium, plan.segmento);
    final (badgeTone, detail) = switch (status) {
      PlanStatus.premium => (
        StatusBadgeTone.violet,
        '${formatGs(monthly)}/mes · '
            '${plan.cancelado ? 'no renueva' : 'vence ${formatShortDate(due!)}'}',
      ),
      PlanStatus.vencido => (
        StatusBadgeTone.warn,
        'Venció el ${formatShortDate(due!)} · funciones Premium '
            'deshabilitadas',
      ),
      PlanStatus.sinPlan => (
        StatusBadgeTone.mute,
        'Soporte por incidente '
            '${formatGs(tariffs.amountFor(PaymentConcept.soporte, plan.segmento))}',
      ),
    };
    final actions = [
      ...switch (status) {
        PlanStatus.premium => ['Registrar pago', 'Dar de baja'],
        PlanStatus.vencido => ['Registrar pago y reactivar', 'Dar de baja'],
        PlanStatus.sinPlan => ['Activar Premium'],
      },
      plan.segmento == Segment.b2c ? 'Pasar a B2B' : 'Pasar a B2C',
    ];
    final devices = row.devices;
    final active = devices.any((d) => d.activo);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: glassCardDecoration(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(
            Icons.memory,
            color: active ? AppColors.cyan : AppColors.textMute,
            size: 18,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        row.user.fullName,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StatusBadge(
                      text: plan.segmento.id,
                      tone: StatusBadgeTone.mute,
                    ),
                  ],
                ),
                Text(
                  devices.isEmpty
                      ? 'Sin dispositivo asignado'
                      : devices.map((d) => d.title).join(', '),
                  style: muted,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(text: status.label, tone: badgeTone),
                    Text(detail, style: muted),
                  ],
                ),
                if (due != null && status != PlanStatus.sinPlan) ...[
                  Text(
                    (late ? 'Debía pagar' : 'Próximo pago').toUpperCase(),
                    style: AppTextStyles.mono(
                      fontSize: 9.5,
                      color: late ? AppColors.amber : AppColors.textMute,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: late
                            ? AppColors.amber.withValues(alpha: 0.5)
                            : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: late ? AppColors.amber : AppColors.cyan,
                        ),
                        Text(
                          formatLongDate(due),
                          style: AppTextStyles.body(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      _ActionButton(
                        action,
                        onPressed: () => onAction(action),
                        danger: action == 'Dar de baja',
                      ),
                  ],
                ),
                if (plan.ultimoCambio.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      text: 'Último cambio: ',
                      children: [
                        TextSpan(
                          text: plan.ultimoCambio,
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: [
                            '',
                            if (plan.autorUltimoCambio.isNotEmpty)
                              plan.autorUltimoCambio,
                            if (plan.fechaUltimoCambio != null)
                              formatShortDate(plan.fechaUltimoCambio!),
                          ].join(' · '),
                        ),
                      ],
                    ),
                    style: AppTextStyles.body(
                      fontSize: 10.5,
                      color: AppColors.textMute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffField extends StatelessWidget {
  const _TariffField({required this.tariff, required this.controller});

  final Tariff tariff;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    decoration: glassCardDecoration(radius: 14),
    child: Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tariff.label,
                style: AppTextStyles.body(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                tariff.sub,
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.textMute,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: AppTextStyles.body(fontSize: 13),
            decoration: appFieldDecoration().copyWith(
              prefixText: 'Gs. ',
              prefixStyle: AppTextStyles.mono(fontSize: 11),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.num, required this.label, this.numColor});

  final String num;
  final String label;
  final Color? numColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        children: [
          Text(
            num,
            style: AppTextStyles.display(fontSize: 20, color: numColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 10.5,
              color: AppColors.textMute,
            ),
          ),
        ],
      ),
    );
  }
}
