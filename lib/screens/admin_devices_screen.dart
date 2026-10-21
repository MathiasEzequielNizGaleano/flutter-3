import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'admin_plans_screen.dart';

class _DeviceEntry {
  const _DeviceEntry(
    this.name,
    this.owner,
    this.mac,
    this.calibration,
    this.active,
    this.changeLabel,
    this.changeDetail,
  );

  final String name;
  final String owner;
  final String mac;
  final String calibration;
  final bool active;

  final String changeLabel;
  final String changeDetail;
}

const _devices = [
  _DeviceEntry(
    'HeadMouse Pro · #0231',
    'Paciente: Juan Paredes',
    'AA:BB:CC:DD:EE:FF',
    'Última calibración: Hoy, 09:12',
    true,
    'Plan Premium renovado',
    'admin_root · Hoy 10:20',
  ),
  _DeviceEntry(
    'HeadMouse Pro · #0198',
    'Paciente: Marcos Rojas',
    '10:1A:2B:3C:4D:5E',
    'Última calibración: Ayer, 18:40',
    true,
    'Pago registrado (QR Bancard)',
    'admin_root · 15 sep',
  ),
  _DeviceEntry(
    'HeadMouse Pro · #0087',
    'Paciente: Lucía Fernández',
    'C4:D5:E6:F7:08:19',
    'Última calibración: 20 jun, 11:05',
    false,
    'Plan Premium dado de baja',
    'admin_root · 02 sep',
  ),
  _DeviceEntry(
    'HeadMouse Pro · Respaldo #0045',
    'Paciente: Ana Torres',
    '11:22:33:44:55:66',
    'Última calibración: 12 jul, 14:30',
    false,
    'Plan vencido, funciones deshabilitadas',
    'Sistema · 12 sep',
  ),
];

class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final visible = _devices.where((device) {
      if (_filter == 'Activos') return device.active;
      if (_filter == 'Inactivos') return !device.active;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Estado de dispositivos',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                Row(
                  spacing: 10,
                  children: const [
                    Expanded(
                      child: _StatCard(num: '94', label: 'Total'),
                    ),
                    Expanded(
                      child: _StatCard(num: '71', label: 'Activos'),
                    ),
                    Expanded(
                      child: _StatCard(num: '23', label: 'Inactivos'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: glassCardDecoration(radius: 14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPlansScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gestionar planes y tarifas',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.cyan,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilterChips(
                  options: const ['Todos', 'Activos', 'Inactivos'],
                  selected: _filter,
                  onChanged: (chip) => setState(() => _filter = chip),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const EmptyState(
                    title: 'No hay dispositivos',
                    message:
                        'Ningún dispositivo coincide con el filtro seleccionado.',
                    icon: Icons.memory,
                  ),
                for (final device in visible)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: glassCardDecoration(radius: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Icon(
                          Icons.memory,
                          color: device.active
                              ? AppColors.cyan
                              : AppColors.textMute,
                          size: 18,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              Text(
                                device.owner,
                                style: AppTextStyles.body(
                                  fontSize: 11,
                                  color: AppColors.textMute,
                                ),
                              ),
                              Text(
                                device.mac,
                                style: AppTextStyles.mono(fontSize: 11),
                              ),
                              Text(
                                device.calibration,
                                style: AppTextStyles.body(
                                  fontSize: 11,
                                  color: AppColors.textMute,
                                ),
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
                  ),
              ],
            ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.num, required this.label});

  final String num;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        children: [
          Text(num, style: AppTextStyles.display(fontSize: 20)),
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
