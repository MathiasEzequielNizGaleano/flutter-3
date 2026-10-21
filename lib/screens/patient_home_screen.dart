import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/battery_ring.dart';
import 'device_ble_scan_screen.dart';
import 'patient_caregivers_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

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
              ScreenTitle('Hola, Marcos'),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BatteryRing(batteryLevel: 0.85),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CONECTADO',
                        style: AppTextStyles.mono(
                          fontSize: 10,
                          color: AppColors.cyan,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  border: Border.all(color: AppColors.line, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  spacing: 9,
                  children: [
                    _StatusRow(label: 'Estado del sensor', value: 'Listo'),
                    _StatusRow(
                      label: 'MAC Bluetooth',
                      value: 'AA:BB:CC:DD:EE:FF',
                    ),
                    _StatusRow(
                      label: 'Última calibración',
                      value: 'Hoy, 09:12',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'MI CUIDADOR',
                style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PatientCaregiversScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.overlay,
                    border: Border.all(color: AppColors.line, width: 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                            'MG',
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
                              'María González',
                              style: AppTextStyles.body(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Madre · principal',
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
                          color: AppColors.cyan,
                          boxShadow: [
                            BoxShadow(color: AppColors.cyan, blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceBleScanScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.line, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Conectar y configurar',
                    style: AppTextStyles.body(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: patientHomeNavItems(),
        currentIndex: 0,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

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
