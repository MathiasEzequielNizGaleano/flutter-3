import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/state_views.dart';

class _PatientEntry {
  const _PatientEntry(this.initials, this.name, this.meta, this.connected);

  final String initials;
  final String name;
  final String meta;
  final bool connected;
}

const _patients = [
  _PatientEntry('MR', 'Marcos Rojas', 'Principal · Conectado', true),
  _PatientEntry('LF', 'Lucía Fernández', 'Secundario · Desconectado', false),
  _PatientEntry('JP', 'Juan Paredes', 'Principal · Conectado', true),
];

class CaregiverPatientsScreen extends StatelessWidget {
  const CaregiverPatientsScreen({super.key});

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
                ScreenTitle('Mis pacientes'),
                const SizedBox(height: 18),
                for (final patient in _patients)
                  Container(
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
                              patient.initials,
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
                                patient.name,
                                style: AppTextStyles.body(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                patient.meta,
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
                            color: patient.connected
                                ? AppColors.cyan
                                : AppColors.textMute,
                            boxShadow: patient.connected
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
                const SizedBox(height: 8),
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
                      _SummaryRow(label: 'Pacientes asignados', value: '3'),
                      _SummaryRow(label: 'Dispositivos activos', value: '2'),
                      _SummaryRow(label: 'Calibraciones hoy', value: '1'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: caregiverNavItems(),
        currentIndex: 0,
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
