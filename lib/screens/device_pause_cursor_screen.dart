import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/status_badge.dart';
import 'device_settings_screen.dart';

class DevicePauseCursorScreen extends StatefulWidget {
  const DevicePauseCursorScreen({super.key, this.showPatientNav = true});

  final bool showPatientNav;

  @override
  State<DevicePauseCursorScreen> createState() =>
      _DevicePauseCursorScreenState();
}

class _DevicePauseCursorScreenState extends State<DevicePauseCursorScreen> {
  final _ble = HeadMouseBle.instance;
  bool _busy = false;

  Future<void> _pauseAndContinue() async {
    setState(() => _busy = true);
    try {
      await _ble.setConfigMode(true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DeviceSettingsScreen(showPatientNav: widget.showPatientNav),
        ),
      );
    } on HeadMouseException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    await _ble.disconnect();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          'HeadMouse Pro',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _ble,
          builder: (context, _) {
            final connected = _ble.isConnected;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  StatusBadge(
                    text: connected ? 'Conectado' : 'Desconectado',
                    tone: connected ? StatusBadgeTone.ok : StatusBadgeTone.mute,
                  ),
                  if (!connected && _ble.disconnectMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _ble.disconnectMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 18,
                    ),
                    decoration: glassCardDecoration(radius: 18),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.coral.withValues(alpha: 0.14),
                          ),
                          child: Icon(
                            Icons.pause,
                            color: AppColors.coral,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Pausar cursor y clics',
                          style: AppTextStyles.display(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Antes de ajustar la configuración, desactivamos el '
                          'movimiento del cursor y los clics para que puedas '
                          'editar los parámetros sin que el mouse se mueva solo.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            fontSize: 12.5,
                            color: AppColors.textMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [AppColors.coral, const Color(0xFFF2954C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.coral.withValues(alpha: 0.5),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: connected && !_busy ? _pauseAndContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _busy ? 'Pausando…' : 'Pausar cursor y continuar',
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2A0F02),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.line, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        connected ? 'Cancelar y desconectar' : 'Volver',
                        style: AppTextStyles.body(color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
