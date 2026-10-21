import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_badge.dart';
import '../widgets/unsaved_changes_guard.dart';

enum _PlanState { premium, none, expired }

class _PlanDevice {
  const _PlanDevice({
    required this.name,
    required this.owner,
    required this.segment,
    required this.active,
    required this.state,
    required this.planDetail,
    required this.dateLabel,
    required this.date,
    required this.actions,
    required this.changeLabel,
    required this.changeDetail,
  });

  final String name;
  final String owner;
  final String segment;
  final bool active;
  final _PlanState state;
  final String planDetail;
  final String dateLabel;
  final String date;
  final List<String> actions;
  final String changeLabel;
  final String changeDetail;
}

const _planDevices = [
  _PlanDevice(
    name: 'HeadMouse Pro · #0231',
    owner: 'Paciente: Juan Paredes',
    segment: 'B2B',
    active: true,
    state: _PlanState.premium,
    planDetail: 'Gs. 500.000/mes · vence 30 oct',
    dateLabel: 'Fecha de pago',
    date: '30/10/2026',
    actions: ['Registrar pago', 'Dar de baja'],
    changeLabel: 'Plan renovado',
    changeDetail: 'admin_root · Hoy 10:20',
  ),
  _PlanDevice(
    name: 'HeadMouse Pro · #0198',
    owner: 'Paciente: Marcos Rojas',
    segment: 'B2C',
    active: true,
    state: _PlanState.premium,
    planDetail: 'Gs. 200.000/mes · vence 15 oct',
    dateLabel: 'Fecha de pago',
    date: '15/10/2026',
    actions: ['Registrar pago', 'Dar de baja'],
    changeLabel: 'Pago registrado (QR Bancard)',
    changeDetail: 'admin_root · 15 sep',
  ),
  _PlanDevice(
    name: 'HeadMouse Pro · #0087',
    owner: 'Paciente: Lucía Fernández',
    segment: 'B2C',
    active: false,
    state: _PlanState.none,
    planDetail: 'Soporte por incidente Gs. 210.000',
    dateLabel: 'Primera fecha de pago',
    date: 'dd/mm/aaaa',
    actions: ['Activar Premium'],
    changeLabel: 'Plan dado de baja',
    changeDetail: 'admin_root · 02 sep',
  ),
  _PlanDevice(
    name: 'HeadMouse Pro · Respaldo #0045',
    owner: 'Paciente: Ana Torres',
    segment: 'B2B',
    active: false,
    state: _PlanState.expired,
    planDetail: '12 sep · personalización y soporte prioritario deshabilitados',
    dateLabel: 'Debía pagar',
    date: '12/09/2026',
    actions: ['Registrar pago y reactivar'],
    changeLabel: 'Vencimiento automático',
    changeDetail: 'Sistema · 12 sep',
  ),
];

class _Tariff {
  const _Tariff(this.label, this.sub, this.amount);

  final String label;
  final String sub;
  final String amount;
}

const _tariffs = [
  _Tariff('Dispositivo B2C', 'Pago único', '1.550.000'),
  _Tariff('Dispositivo B2B', 'Pago único por unidad', '1.380.000'),
  _Tariff('Plan Premium B2C', 'Mensual', '200.000'),
  _Tariff('Plan Premium B2B', 'Mensual, institucional', '500.000'),
  _Tariff('Soporte sin plan B2C', 'Por solicitud', '210.000'),
  _Tariff('Soporte sin plan B2B', 'Por solicitud', '300.000'),
  _Tariff('Capacitación del personal', 'Por evento, B2B', '350.000'),
];

const _planFilters = ['Todos', 'Premium', 'Sin plan', 'Vencidos', 'B2C', 'B2B'];

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  String _filter = 'Todos';
  late final List<TextEditingController> _tariffControllers = [
    for (final tariff in _tariffs) TextEditingController(text: tariff.amount),
  ];

  late List<String> _savedAmounts = [
    for (final tariff in _tariffs) tariff.amount,
  ];

  bool get _hasUnsavedChanges {
    for (var i = 0; i < _tariffControllers.length; i++) {
      if (_tariffControllers[i].text != _savedAmounts[i]) return true;
    }
    return false;
  }

  void _saveTariffs() {
    setState(() {
      _savedAmounts = [for (final c in _tariffControllers) c.text];
    });
    _showDemoMessage('Tarifas guardadas');
  }

  @override
  void dispose() {
    for (final controller in _tariffControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message (demo, sin backend)')));
  }

  bool _matches(_PlanDevice device) => switch (_filter) {
    'Premium' => device.state == _PlanState.premium,
    'Sin plan' => device.state == _PlanState.none,
    'Vencidos' => device.state == _PlanState.expired,
    'B2C' => device.segment == 'B2C',
    'B2B' => device.segment == 'B2B',
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      listenable: Listenable.merge(_tariffControllers),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Dispositivos y planes',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _StatCard(num: '38', label: 'Premium'),
                  ),
                  Expanded(
                    child: _StatCard(num: '49', label: 'Sin plan'),
                  ),
                  Expanded(
                    child: _StatCard(
                      num: '7',
                      label: 'Vencidos',
                      numColor: AppColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilterChips(
                options: _planFilters,
                selected: _filter,
                onChanged: (chip) => setState(() => _filter = chip),
              ),
              const SizedBox(height: 14),
              for (final device in _planDevices.where(_matches))
                _PlanDeviceCard(
                  device: device,
                  onAction: (action) => _showDemoMessage(action),
                ),
              Text(
                'La fecha de pago que definas en cada dispositivo es la que '
                'ven el paciente y su cuidador en Facturación como “Próximo '
                'pago”. Al registrar un pago, la fecha avanza un mes.',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'TARIFAS Y MONTOS A COBRAR',
                style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _tariffs.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: glassCardDecoration(radius: 14),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tariffs[i].label,
                              style: AppTextStyles.body(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _tariffs[i].sub,
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
                          controller: _tariffControllers[i],
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
                ),
              Text(
                'Los nuevos montos se aplican a los próximos cobros. Cada '
                'cambio queda registrado en Auditoría con el usuario, la '
                'fecha y el valor anterior.',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [AppColors.cyanAccent, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.5),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _saveTariffs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Guardar tarifas',
                      style: AppTextStyles.body(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bgPanel2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 0,
      ),
    );
  }
}

class _PlanDeviceCard extends StatelessWidget {
  const _PlanDeviceCard({required this.device, required this.onAction});

  final _PlanDevice device;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeTone) = switch (device.state) {
      _PlanState.premium => ('Premium', StatusBadgeTone.violet),
      _PlanState.none => ('Sin plan', StatusBadgeTone.mute),
      _PlanState.expired => ('Premium vencido', StatusBadgeTone.warn),
    };
    final late = device.state == _PlanState.expired;
    final muted = AppTextStyles.body(fontSize: 11, color: AppColors.textMute);

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
            color: device.active ? AppColors.cyan : AppColors.textMute,
            size: 18,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StatusBadge(
                      text: device.active ? 'Activo' : 'Inactivo',
                      tone: device.active
                          ? StatusBadgeTone.ok
                          : StatusBadgeTone.warn,
                    ),
                  ],
                ),
                Text('${device.owner} · ${device.segment}', style: muted),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(text: badgeText, tone: badgeTone),
                    Text(device.planDetail, style: muted),
                  ],
                ),
                Text(
                  device.dateLabel.toUpperCase(),
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
                        device.date,
                        style: AppTextStyles.body(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in device.actions)
                      OutlinedButton(
                        onPressed: () => onAction(action),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: action == 'Dar de baja'
                                ? AppColors.coral.withValues(alpha: 0.6)
                                : AppColors.cyan,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          action,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: action == 'Dar de baja'
                                ? AppColors.coral
                                : AppColors.cyan,
                          ),
                        ),
                      ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    text: 'Último cambio: ',
                    children: [
                      TextSpan(
                        text: device.changeLabel,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' · ${device.changeDetail}'),
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
