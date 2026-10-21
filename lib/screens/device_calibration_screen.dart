import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/gradient_button.dart';

const _motivos = [
  'Encendido',
  'Recolocación',
  'Se quitó el dispositivo',
  'Diadema desplazada',
  'Cursor descentrado',
  'Solicitud de usuario',
];

class DeviceCalibrationScreen extends StatefulWidget {
  const DeviceCalibrationScreen({super.key});

  @override
  State<DeviceCalibrationScreen> createState() =>
      _DeviceCalibrationScreenState();
}

class _DeviceCalibrationScreenState extends State<DeviceCalibrationScreen> {
  String _selectedMotivo = 'Recolocación';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Calibración manual',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 150,
                decoration: glassCardDecoration(radius: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 1, color: AppColors.line),
                    Container(width: 1, color: AppColors.line),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cyan,
                        boxShadow: [
                          BoxShadow(color: AppColors.cyan, blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'AX centro ',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textMute,
                      ),
                      children: [
                        TextSpan(
                          text: '3025',
                          style: AppTextStyles.mono(
                            fontSize: 12,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: 'AY centro ',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textMute,
                      ),
                      children: [
                        TextSpan(
                          text: '-1415',
                          style: AppTextStyles.mono(
                            fontSize: 12,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MOTIVO',
                  style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Alto proporcional al tamaño de texto: con texto grande una
                // proporción fija recortaría el contenido.
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent:
                      64 * MediaQuery.textScalerOf(context).scale(1),
                ),
                children: [
                  for (final motivo in _motivos)
                    Semantics(
                      button: true,
                      selected: _selectedMotivo == motivo,
                      label: 'Motivo: $motivo',
                      excludeSemantics: true,
                      onTap: () => setState(() => _selectedMotivo = motivo),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedMotivo = motivo),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedMotivo == motivo
                                ? AppColors.cyan.withValues(alpha: 0.14)
                                : AppColors.overlay,
                            border: Border.all(
                              color: _selectedMotivo == motivo
                                  ? AppColors.cyan
                                  : AppColors.line,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'MOTIVO',
                                style: AppTextStyles.mono(fontSize: 8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                motivo,
                                style: AppTextStyles.body(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedMotivo == motivo
                                      ? AppColors.text
                                      : AppColors.textMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Calibrar centro',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Centro calibrado: $_selectedMotivo (demo, sin dispositivo)',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.line, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Guardar y salir',
                    style: AppTextStyles.body(color: AppColors.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: patientHomeNavItems(),
        currentIndex: 1,
      ),
    );
  }
}
