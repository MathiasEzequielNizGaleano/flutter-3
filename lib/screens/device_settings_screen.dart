import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_badge.dart';
import 'device_calibration_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  double _threshold = 4;
  double _maxSpeed = 15;
  double _moveDelay = 12;
  String _clip1 = 'MOUSE_LEFT';
  String _clip2 = 'MOUSE_RIGHT';

  static const _clipOptions = [
    'MOUSE_LEFT',
    'MOUSE_RIGHT',
    'MOUSE_BACK',
    'MOUSE_FORWARD',
  ];

  void _saveAndResume() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración guardada, cursor reactivado (demo)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'Configuración',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              const StatusBadge(
                text: 'Cursor pausado',
                tone: StatusBadgeTone.warn,
              ),
              const SizedBox(height: 14),
              _SliderBlock(
                name: 'Umbral de movimiento',
                value: _threshold,
                min: 0,
                max: 12,
                onChanged: (value) => setState(() => _threshold = value),
              ),
              _SliderBlock(
                name: 'Velocidad máxima',
                value: _maxSpeed,
                min: 0,
                max: 20,
                onChanged: (value) => setState(() => _maxSpeed = value),
              ),
              _SliderBlock(
                name: 'Delay de movimiento',
                value: _moveDelay,
                min: 0,
                max: 20,
                onChanged: (value) => setState(() => _moveDelay = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FUNCIONES DE LOS BOTONES',
                  style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              _ClipGroup(
                name: 'Botón 1',
                defaultTag: 'Default: MOUSE_LEFT',
                selected: _clip1,
                options: _clipOptions,
                onChanged: (value) => setState(() => _clip1 = value),
              ),
              const SizedBox(height: 14),
              _ClipGroup(
                name: 'Botón 2',
                defaultTag: 'Default: MOUSE_RIGHT',
                selected: _clip2,
                options: _clipOptions,
                onChanged: (value) => setState(() => _clip2 = value),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Guardar y reactivar cursor',
                onPressed: _saveAndResume,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceCalibrationScreen(),
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
                    'Calibración manual',
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

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.name,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String name;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(0),
                style: AppTextStyles.mono(fontSize: 12, color: AppColors.cyan),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.cyan,
              inactiveTrackColor: AppColors.line,
              thumbColor: AppColors.cyan,
              overlayColor: AppColors.cyan.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipGroup extends StatelessWidget {
  const _ClipGroup({
    required this.name,
    required this.defaultTag,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String name;
  final String defaultTag;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        border: Border.all(color: AppColors.line, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 12,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                defaultTag,
                style: AppTextStyles.mono(
                  fontSize: 9,
                  color: AppColors.textMute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected == option
                          ? AppColors.cyan.withValues(alpha: 0.14)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected == option
                            ? AppColors.cyan
                            : AppColors.line,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      option,
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: selected == option
                            ? AppColors.text
                            : AppColors.textMute,
                      ),
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
