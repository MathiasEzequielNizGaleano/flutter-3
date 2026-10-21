import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import 'device_pause_cursor_screen.dart';

class DeviceBleScanScreen extends StatefulWidget {
  const DeviceBleScanScreen({super.key});

  @override
  State<DeviceBleScanScreen> createState() => _DeviceBleScanScreenState();
}

class _DeviceBleScanScreenState extends State<DeviceBleScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _ring(double offset) {
    final t = (_pulse.value + offset) % 1;
    return Container(
      width: 40 + 100 * t,
      height: 40 + 100 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.cyan.withValues(alpha: 0.5 * (1 - t)),
          width: 1.5,
        ),
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
          'Buscar dispositivo',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(0),
                      _ring(1 / 3),
                      _ring(2 / 3),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cyan.withValues(alpha: 0.14),
                          border: Border.all(color: AppColors.cyan),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.5),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.bluetooth_searching,
                          color: AppColors.cyan,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Buscando HeadMouse Pro cerca tuyo…',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMute,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: glassCardDecoration(radius: 14),
                child: Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.memory, color: AppColors.cyan, size: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HeadMouse Pro',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'AA:BB:CC:DD:EE:FF',
                          style: AppTextStyles.mono(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Conectar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DevicePauseCursorScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
