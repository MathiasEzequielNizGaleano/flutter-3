import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'caregiver_detail_screen.dart';

class _CaregiverEntry {
  const _CaregiverEntry(this.info, this.meta, this.connected);

  final CaregiverInfo info;
  final String meta;
  final bool connected;
}

const _caregivers = [
  _CaregiverEntry(
    CaregiverInfo(
      initials: 'MG',
      name: 'María González',
      role: 'Madre',
      level: 'Principal',
      since: 'Mar 2024',
      canView: true,
      canEdit: true,
      canConfigure: true,
      canCalibrate: true,
    ),
    'Madre · Principal · Conectada',
    true,
  ),
  _CaregiverEntry(
    CaregiverInfo(
      initials: 'CH',
      name: 'Carlos Herrera',
      role: 'Fisioterapeuta',
      level: 'Secundario',
      since: 'Mar 2024',
      canView: true,
      canEdit: true,
      canConfigure: true,
      canCalibrate: false,
    ),
    'Fisioterapeuta · Secundario · Conectado',
    true,
  ),
  _CaregiverEntry(
    CaregiverInfo(
      initials: 'AT',
      name: 'Ana Torres',
      role: 'Enfermera',
      level: 'Secundario',
      since: 'Jun 2025',
      canView: true,
      canEdit: false,
      canConfigure: false,
      canCalibrate: false,
    ),
    'Enfermera · Secundario · Desconectada',
    false,
  ),
];

class PatientCaregiversScreen extends StatelessWidget {
  const PatientCaregiversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenTitle('Mis cuidadores'),
                const SizedBox(height: 18),
                for (final caregiver in _caregivers)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CaregiverDetailScreen(caregiver: caregiver.info),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: glassCardDecoration(radius: 14),
                      child: Row(
                        spacing: 12,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.violet, AppColors.cyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                caregiver.info.initials,
                                style: AppTextStyles.display(
                                  fontSize: 13,
                                  color: AppColors.bgPanel2,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  caregiver.info.name,
                                  style: AppTextStyles.body(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  caregiver.meta,
                                  style: AppTextStyles.body(
                                    fontSize: 11,
                                    color: AppColors.textMute,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: caregiver.connected
                                  ? AppColors.cyan
                                  : AppColors.textMute,
                              boxShadow: caregiver.connected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.cyan,
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'MIS DISPOSITIVOS',
                  style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
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
                      Icon(Icons.memory, color: AppColors.cyan, size: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'HeadMouse Pro · Principal',
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const StatusBadge(text: 'Activo'),
                              ],
                            ),
                            Text(
                              'AA:BB:CC:DD:EE:FF',
                              style: AppTextStyles.mono(fontSize: 11),
                            ),
                            Text(
                              'Última calibración: Hoy, 09:12',
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
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: glassCardDecoration(radius: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Icon(Icons.memory, color: AppColors.textMute, size: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'HeadMouse Pro · Respaldo',
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const StatusBadge(
                                  text: 'Inactivo',
                                  tone: StatusBadgeTone.warn,
                                ),
                              ],
                            ),
                            Text(
                              '11:22:33:44:55:66',
                              style: AppTextStyles.mono(fontSize: 11),
                            ),
                            Text(
                              'Última calibración: 12 jul, 14:30',
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
                ),
                const SizedBox(height: 18),
                Text(
                  'RESUMEN',
                  style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: glassCardDecoration(),
                  child: Column(
                    spacing: 9,
                    children: [
                      _SummaryRow(label: 'Cuidadores asignados', value: '3'),
                      _SummaryRow(label: 'Dispositivos activos', value: '1'),
                      _SummaryRow(
                        label: 'Última calibración',
                        value: 'Hoy, 09:12',
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
        items: patientCaregiversNavItems(),
        currentIndex: 1,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.mono(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}
