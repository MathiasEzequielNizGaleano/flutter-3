import 'package:flutter/material.dart';

import '../ble/headmouse_ble.dart';
import '../navigation/nav_items.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/device_live_panel.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_badge.dart';
import 'device_ble_scan_screen.dart';
import 'device_calibration_screen.dart';
import 'device_history_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key, this.showPatientNav = true});

  final bool showPatientNav;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final _ble = HeadMouseBle.instance;

  /// Lo que el usuario está editando. Arranca con lo que tiene el ESP32.
  late DeviceConfig _draft = _ble.config ?? DeviceConfig.defaults;
  bool _edited = false;
  bool _saving = false;

  /// Paciente con el que se usa el HeadMouse (null en pruebas sin sesión).
  final DevicePatient? _patient = DeviceService.activePatient;
  ConfigOrigin _origin = ConfigOrigin.app;
  late final Stream<List<ConfigEntry>>? _configs = _patient == null
      ? null
      : DeviceService.instance.watchConfigs(_patient.uid);

  bool get _canConfigure => _patient?.puedeConfigurar ?? true;
  bool get _canCalibrate => _patient?.puedeCalibrar ?? true;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_syncFromDevice);
  }

  @override
  void dispose() {
    _ble.removeListener(_syncFromDevice);
    super.dispose();
  }

  /// Si llega la configuración del dispositivo y el usuario no tocó nada,
  /// la mostramos.
  void _syncFromDevice() {
    final remote = _ble.config;
    if (!_edited && remote != null && remote != _draft) {
      setState(() => _draft = remote);
    }
  }

  void _update(DeviceConfig next, {ConfigOrigin origin = ConfigOrigin.app}) =>
      setState(() {
        _draft = next;
        _origin = origin;
        _edited = true;
      });

  /// Aplica en el HeadMouse, lo guarda en el historial del paciente y suelta
  /// el equipo para que la computadora pueda volver a usarlo.
  Future<void> _saveAndResume() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final applied = await _ble.saveConfig(_draft);
      final historyNote = await _record(applied);
      await _ble.setConfigMode(false);
      await _ble.disconnect();
      _edited = false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Configuración guardada en el HeadMouse. Cursor reactivado: ya '
            'podés usarlo con la computadora.$historyNote',
          ),
        ),
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } on HeadMouseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Devuelve un aviso si no se pudo guardar en Firestore. El HeadMouse ya
  /// quedó configurado, así que no se trata como error.
  Future<String> _record(DeviceConfig applied) async {
    final patient = _patient;
    if (patient == null) return '';
    try {
      await DeviceService.instance.recordConfig(
        patient,
        applied,
        mac: _ble.mac,
        origen: _origin,
      );
      return '';
    } catch (e) {
      return ' (No se pudo guardar en el historial: '
          '${AuthService.describeError(e)})';
    }
  }

  Future<void> _openHistory(bool canRestore) async {
    final patient = _patient!;
    final restored = await Navigator.push<DeviceConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceHistoryScreen(
          patientUid: patient.uid,
          patientName: patient.nombre,
          canRestore: canRestore,
        ),
      ),
    );
    if (restored != null && mounted) {
      _update(restored, origin: ConfigOrigin.recuperada);
    }
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
        child: ListenableBuilder(
          listenable: _ble,
          builder: (context, _) {
            final connected = _ble.isConnected;
            final editable = connected && !_saving && _canConfigure;
            final patient = _patient;
            final mac = _ble.mac;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  if (patient != null) ...[
                    Text(
                      'Paciente: ${patient.nombre}',
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  StatusBadge(
                    text: !connected
                        ? 'Sin conexión'
                        : _ble.configMode
                        ? 'Cursor pausado'
                        : 'Cursor activo',
                    tone: !connected
                        ? StatusBadgeTone.mute
                        : _ble.configMode
                        ? StatusBadgeTone.warn
                        : StatusBadgeTone.ok,
                  ),
                  const SizedBox(height: 14),
                  if (connected)
                    const DeviceLivePanel()
                  else
                    _NotConnectedCard(
                      message: _ble.disconnectMessage,
                      onSearch: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceBleScanScreen(
                            showPatientNav: widget.showPatientNav,
                          ),
                        ),
                      ),
                    ),
                  if (!_canConfigure)
                    _Notice(
                      'No tenés permiso para configurar el HeadMouse de '
                      '${patient?.nombre ?? 'este paciente'}. Lo otorga el '
                      'administrador.',
                    ),
                  if (connected && mac != null && patient != null)
                    _RegistrationNote(mac: mac, patient: patient),
                  if (_configs != null)
                    StreamBuilder<List<ConfigEntry>>(
                      stream: _configs,
                      builder: (context, snapshot) {
                        final pending = snapshot.data?.where(
                          (e) => e.pendiente,
                        );
                        if (pending == null || pending.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _Notice(
                          'El administrador pidió restablecer este HeadMouse '
                          'a los valores de fábrica. Cargalos y guardá para '
                          'aplicarlos.',
                          action: 'Cargar valores de fábrica',
                          onAction: editable
                              ? () => _update(
                                  pending.first.config,
                                  origin: ConfigOrigin.restablecida,
                                )
                              : null,
                        );
                      },
                    ),
                  const SizedBox(height: 14),
                  _SliderBlock(
                    name: 'Umbral de movimiento',
                    hint: '3 más sensible · 6 más estable',
                    value: _draft.umbralMovimiento,
                    range: DeviceConfig.umbralRange,
                    onChanged: editable
                        ? (v) => _update(_draft.copyWith(umbralMovimiento: v))
                        : null,
                  ),
                  _SliderBlock(
                    name: 'Velocidad máxima',
                    hint: '1 más lento · 20 más rápido',
                    value: _draft.velocidadMax,
                    range: DeviceConfig.velocidadRange,
                    onChanged: editable
                        ? (v) => _update(_draft.copyWith(velocidadMax: v))
                        : null,
                  ),
                  _SliderBlock(
                    name: 'Delay de movimiento (ms)',
                    hint:
                        '≈ ${(1000 / _draft.delayMovimiento).round()} '
                        'actualizaciones por segundo',
                    value: _draft.delayMovimiento,
                    range: DeviceConfig.delayRange,
                    onChanged: editable
                        ? (v) => _update(_draft.copyWith(delayMovimiento: v))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FUNCIONES DE LOS BOTONES',
                      style: AppTextStyles.mono(
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ClipGroup(
                    name: 'Botón 1',
                    defaultTag: 'Default: MOUSE_LEFT',
                    selected: _draft.boton1,
                    onChanged: editable
                        ? (v) => _update(_draft.copyWith(boton1: v))
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _ClipGroup(
                    name: 'Botón 2',
                    defaultTag: 'Default: MOUSE_RIGHT',
                    selected: _draft.boton2,
                    onChanged: editable
                        ? (v) => _update(_draft.copyWith(boton2: v))
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: editable && _draft != DeviceConfig.defaults
                          ? () => _update(
                              DeviceConfig.defaults,
                              origin: ConfigOrigin.restablecida,
                            )
                          : null,
                      child: Text(
                        'Restablecer valores de fábrica',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: editable ? AppColors.cyan : AppColors.textMute,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: _saving
                        ? 'Guardando…'
                        : 'Guardar y reactivar cursor',
                    onPressed: editable ? _saveAndResume : null,
                  ),
                  const SizedBox(height: 10),
                  _SecondaryButton(
                    'Calibración manual',
                    onPressed: _saving || !_canCalibrate
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeviceCalibrationScreen(
                                  showPatientNav: widget.showPatientNav,
                                ),
                              ),
                            );
                          },
                  ),
                  if (patient != null) ...[
                    const SizedBox(height: 10),
                    _SecondaryButton(
                      'Historial de configuraciones',
                      onPressed: _saving ? null : () => _openHistory(editable),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: widget.showPatientNav
          ? patientBottomNav(PatientTab.dispositivo)
          : null,
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(this.label, {required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.line, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: AppTextStyles.body(
          color: onPressed == null ? AppColors.textMute : AppColors.text,
        ),
      ),
    ),
  );
}

/// Aviso en ámbar, con una acción opcional.
class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppTextStyles.body(fontSize: 12)),
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                child: Text(
                  action!,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onAction == null
                        ? AppColors.textMute
                        : AppColors.amber,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Si el HeadMouse conectado está registrado para el paciente. No bloquea
/// nada: solo avisa, porque puede ser un equipo de préstamo.
class _RegistrationNote extends StatefulWidget {
  const _RegistrationNote({required this.mac, required this.patient});

  final String mac;
  final DevicePatient patient;

  @override
  State<_RegistrationNote> createState() => _RegistrationNoteState();
}

class _RegistrationNoteState extends State<_RegistrationNote> {
  late Future<HeadMouseDevice?> _device = _find();

  Future<HeadMouseDevice?> _find() =>
      DeviceService.instance.findDevice(widget.mac);

  @override
  void didUpdateWidget(_RegistrationNote old) {
    super.didUpdateWidget(old);
    if (old.mac != widget.mac) _device = _find();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HeadMouseDevice?>(
      future: _device,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final device = snapshot.data;
        if (device != null && device.idPaciente == widget.patient.uid) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${device.title} · registrado para ${widget.patient.nombre}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.textMute,
              ),
            ),
          );
        }
        return _Notice(
          'Este HeadMouse no está registrado para ${widget.patient.nombre}. '
          'Podés usarlo igual; pedile al administrador que lo registre para '
          'ver su estado en el panel.',
        );
      },
    );
  }
}

class _NotConnectedCard extends StatelessWidget {
  const _NotConnectedCard({required this.onSearch, this.message});

  final VoidCallback onSearch;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            message ?? 'No hay un HeadMouse Pro conectado.',
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: message != null ? AppColors.coral : AppColors.text,
            ),
          ),
          Text(
            'Conectalo para leer y cambiar su configuración. Abajo se ve la '
            'última configuración conocida.',
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMute),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onSearch,
              icon: Icon(Icons.bluetooth_searching, color: AppColors.cyan),
              label: Text(
                'Buscar dispositivo',
                style: AppTextStyles.body(fontSize: 13, color: AppColors.text),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.line, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.name,
    required this.hint,
    required this.value,
    required this.range,
    required this.onChanged,
  });

  final String name;
  final String hint;
  final int value;
  final ParamRange range;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                '$value',
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
              value: range.clamp(value).toDouble(),
              min: range.min.toDouble(),
              max: range.max.toDouble(),
              divisions: range.max - range.min,
              label: '$value',
              semanticFormatterCallback: (v) => '$name: ${v.round()}',
              onChanged: change == null ? null : (v) => change(v.round()),
            ),
          ),
          Text(
            hint,
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

class _ClipGroup extends StatelessWidget {
  const _ClipGroup({
    required this.name,
    required this.defaultTag,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final String defaultTag;
  final ButtonAction selected;
  final ValueChanged<ButtonAction>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
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
              for (final option in ButtonAction.values)
                Semantics(
                  button: true,
                  selected: selected == option,
                  enabled: change != null,
                  label: '$name: ${option.label}',
                  excludeSemantics: true,
                  onTap: change == null ? null : () => change(option),
                  child: GestureDetector(
                    onTap: change == null ? null : () => change(option),
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
                        option.firmwareName,
                        style: AppTextStyles.mono(
                          fontSize: 10,
                          color: selected == option
                              ? AppColors.text
                              : AppColors.textMute,
                        ),
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
