import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import 'device_pause_cursor_screen.dart';

class DeviceBleScanScreen extends StatefulWidget {
  const DeviceBleScanScreen({super.key, this.showPatientNav = true});

  /// false cuando entra un cuidador (no se muestra la barra del paciente).
  final bool showPatientNav;

  @override
  State<DeviceBleScanScreen> createState() => _DeviceBleScanScreenState();
}

class _DeviceBleScanScreenState extends State<DeviceBleScanScreen>
    with SingleTickerProviderStateMixin {
  final _ble = HeadMouseBle.instance;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  String? _selectedId;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ble.startScan());
  }

  @override
  void dispose() {
    _ble.stopScan();
    _pulse.dispose();
    super.dispose();
  }

  HeadMouseFound? get _selected {
    final found = _ble.found;
    if (found.isEmpty) return null;
    return found.firstWhere(
      (f) => f.id == _selectedId,
      orElse: () => found.first,
    );
  }

  Future<void> _connect() async {
    final target = _selected;
    if (target == null) return;
    setState(() => _connecting = true);
    try {
      await _ble.connect(target);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DevicePauseCursorScreen(showPatientNav: widget.showPatientNav),
        ),
      );
    } on HeadMouseException catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
        child: ListenableBuilder(
          listenable: _ble,
          builder: (context, _) {
            final scanning = _ble.scanning;
            final found = _ble.found;
            final selected = _selected;
            return SingleChildScrollView(
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
                          if (scanning) ...[
                            _ring(0),
                            _ring(1 / 3),
                            _ring(2 / 3),
                          ],
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
                              scanning
                                  ? Icons.bluetooth_searching
                                  : Icons.bluetooth,
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
                    scanning
                        ? 'Buscando HeadMouse Pro cerca tuyo…'
                        : found.isEmpty
                        ? 'No se encontró ningún HeadMouse Pro.'
                        : 'Elegí tu HeadMouse Pro.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMute,
                    ),
                  ),
                  if (_ble.scanError != null) ...[
                    const SizedBox(height: 12),
                    _Notice(text: _ble.scanError!, color: AppColors.coral),
                  ] else if (!scanning && found.isEmpty) ...[
                    const SizedBox(height: 12),
                    const _Notice(
                      text:
                          '• Verificá que esté encendido (LED).\n'
                          '• Si está conectado a la computadora, desconectalo: '
                          'acepta una sola conexión a la vez.\n'
                          '• En Android 11 o anterior, activá la ubicación.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  for (final device in found)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeviceTile(
                        device: device,
                        selected: device.id == selected?.id,
                        onTap: () => setState(() => _selectedId = device.id),
                      ),
                    ),
                  const SizedBox(height: 10),
                  GradientButton(
                    label: _connecting ? 'Conectando…' : 'Conectar',
                    onPressed: selected == null || _connecting
                        ? null
                        : _connect,
                  ),
                  if (!scanning) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _connecting ? null : _ble.startScan,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.line, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Buscar de nuevo',
                          style: AppTextStyles.body(color: AppColors.text),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final HeadMouseFound device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = device.alreadyConnected
        ? 'Vinculado al teléfono'
        : device.rssi == null
        ? null
        : 'Señal ${device.rssi} dBm';
    return Semantics(
      button: true,
      selected: selected,
      label: '${device.name} ${device.id}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: glassCardDecoration(radius: 14).copyWith(
            color: selected ? AppColors.cyan.withValues(alpha: 0.14) : null,
            border: Border.all(
              color: selected ? AppColors.cyan : AppColors.line,
              width: 1,
            ),
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(Icons.memory, color: AppColors.cyan, size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(device.id, style: AppTextStyles.mono(fontSize: 11)),
                  ],
                ),
              ),
              if (detail != null)
                Text(
                  detail,
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: AppColors.textMute,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: glassCardDecoration(radius: 12),
      child: Text(
        text,
        style: AppTextStyles.body(
          fontSize: 12,
          color: color ?? AppColors.textMute,
        ),
      ),
    );
  }
}
