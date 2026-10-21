import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import 'admin_audit_screen.dart';
import 'admin_devices_screen.dart';

class _AdminAction {
  const _AdminAction(this.icon, this.label, this.builder);

  final IconData icon;
  final String label;
  final WidgetBuilder? builder;
}

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      const _AdminAction(
        Icons.people_outline,
        'Gestionar usuarios y roles',
        null,
      ),
      _AdminAction(
        Icons.shield_outlined,
        'Ver registros de auditoría',
        (_) => const AdminAuditScreen(),
      ),
      _AdminAction(
        Icons.medical_information_outlined,
        'Editar diagnósticos',
        adminNavItems()[2].builder,
      ),
      _AdminAction(
        Icons.devices_other,
        'Estado de dispositivos',
        (_) => const AdminDevicesScreen(),
      ),
      const _AdminAction(
        Icons.insert_chart_outlined,
        'Reportes de pacientes y calibraciones',
        null,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle('Panel general'),
              const SizedBox(height: 18),
              Row(
                spacing: 10,
                children: const [
                  Expanded(
                    child: _StatCard(num: '128', label: 'Usuarios'),
                  ),
                  Expanded(
                    child: _StatCard(num: '94', label: 'Dispositivos'),
                  ),
                  Expanded(
                    child: _StatCard(num: '3', label: 'Alertas'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'ACCIONES',
                style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              for (final action in actions)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: glassCardDecoration(radius: 14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: action.builder == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: action.builder!),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                        child: Row(
                          spacing: 12,
                          children: [
                            Icon(action.icon, color: AppColors.cyan, size: 20),
                            Expanded(
                              child: Text(
                                action.label,
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
