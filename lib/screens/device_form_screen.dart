import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';

const _unassigned = '';

/// Alta ([device] = null) o edición de un HeadMouse Pro por el
/// administrador: código, MAC, firmware, paciente y estado. Al guardar
/// vuelve con el mensaje a mostrar.
class DeviceFormScreen extends StatefulWidget {
  const DeviceFormScreen({super.key, this.device});

  final HeadMouseDevice? device;

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.device?.codigo);
  late final _mac = TextEditingController(text: widget.device?.mac);
  late final _firmware = TextEditingController(
    text: widget.device?.versionFirmware,
  );
  late String _patientUid = widget.device?.idPaciente ?? _unassigned;
  late bool _active = widget.device?.activo ?? true;
  late final Stream<List<ManagedUser>> _users = AdminService.instance
      .watchUsers();
  List<ManagedUser> _patients = const [];
  bool _saving = false;

  bool get _isNew => widget.device == null;

  @override
  void dispose() {
    _code.dispose();
    _mac.dispose();
    _firmware.dispose();
    super.dispose();
  }

  ManagedUser? get _selectedPatient {
    for (final p in _patients) {
      if (p.uid == _patientUid) return p;
    }
    final device = widget.device;
    // El paciente actual puede no estar en la lista (por ejemplo, de baja).
    if (device != null && device.idPaciente == _patientUid) {
      return ManagedUser(
        uid: _patientUid,
        email: '',
        role: UserRole.paciente,
        nombres: device.nombrePaciente,
      );
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final patient = _patientUid == _unassigned ? null : _selectedPatient;
    await _run(
      () => DeviceService.instance.saveDevice(
        widget.device,
        codigo: _code.text,
        mac: _mac.text,
        versionFirmware: _firmware.text,
        paciente: patient,
        activo: _active,
      ),
      _isNew ? 'Dispositivo registrado.' : 'Cambios guardados.',
    );
  }

  Future<void> _factoryReset() async {
    final device = widget.device!;
    final confirmed = await confirmAction(
      context,
      title: '¿Restablecer a valores de fábrica?',
      message:
          'La próxima vez que ${device.nombrePaciente} o su cuidador se '
          'conecten a ${device.title}, la app les va a pedir aplicar la '
          'configuración de fábrica (umbral 3, velocidad 20, delay 13 ms, '
          'clic izquierdo y derecho). La configuración actual queda en el '
          'historial.',
      confirmLabel: 'Sí, restablecer',
    );
    if (!confirmed) return;
    await _run(
      () => DeviceService.instance.requestFactoryReset(device),
      'Restablecimiento pedido. Se aplica en la próxima conexión.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          _isNew ? 'Registrar dispositivo' : 'Dispositivo',
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ManagedUser>>(
          stream: _users,
          builder: (context, snapshot) {
            _patients = [
              for (final u in snapshot.data ?? const <ManagedUser>[])
                if (u.role == UserRole.paciente && u.active) u,
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionLabel('Equipo'),
                    AppTextField(
                      controller: _code,
                      hint: 'Código interno (ej. 0231)',
                      icon: Icons.qr_code_2,
                      capitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe el código del equipo.'
                          : null,
                    ),
                    if (_isNew)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _mac,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9A-Fa-f:\-]'),
                            ),
                            LengthLimitingTextInputFormatter(17),
                          ],
                          validator: (v) => isValidMac(v ?? '')
                              ? null
                              : 'MAC inválida. Formato: AA:BB:CC:DD:EE:FF',
                          style: AppTextStyles.mono(fontSize: 13),
                          decoration: appFieldDecoration(
                            hintText: 'MAC Bluetooth (AA:BB:CC:DD:EE:FF)',
                            icon: Icons.bluetooth,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'MAC ${device!.mac} (no se puede cambiar)',
                          style: AppTextStyles.mono(
                            fontSize: 12,
                            color: AppColors.textMute,
                          ),
                        ),
                      ),
                    AppTextField(
                      controller: _firmware,
                      hint: 'Versión de firmware (opcional)',
                      icon: Icons.memory,
                      capitalization: TextCapitalization.none,
                    ),
                    const FormSectionLabel('Paciente'),
                    DropdownButtonFormField<String>(
                      initialValue: _patientUid,
                      isExpanded: true,
                      dropdownColor: AppColors.bgPanel,
                      decoration: appFieldDecoration(
                        icon: Icons.person_outline,
                      ),
                      style: AppTextStyles.body(fontSize: 13),
                      items: [
                        const DropdownMenuItem(
                          value: _unassigned,
                          child: Text('Sin asignar (en depósito)'),
                        ),
                        for (final p in _patients)
                          DropdownMenuItem(
                            value: p.uid,
                            child: Text(
                              p.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (_patientUid != _unassigned &&
                            !_patients.any((p) => p.uid == _patientUid))
                          DropdownMenuItem(
                            value: _patientUid,
                            child: Text(
                              _selectedPatient?.fullName ?? 'Paciente',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (uid) =>
                          setState(() => _patientUid = uid ?? _unassigned),
                    ),
                    if (!_isNew) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: glassCardDecoration(radius: 14),
                        child: Material(
                          type: MaterialType.transparency,
                          child: YesNoSwitch(
                            'Equipo activo',
                            _active,
                            (v) => setState(() => _active = v),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      label: _saving
                          ? 'Guardando…'
                          : (_isNew ? 'Registrar' : 'Guardar cambios'),
                      onPressed: _saving ? null : _save,
                    ),
                    if (device?.idPaciente != null) ...[
                      const SizedBox(height: 10),
                      OutlineActionButton(
                        label: 'Restablecer valores de fábrica',
                        onPressed: _saving ? null : _factoryReset,
                      ),
                    ],
                    const FormFootnote(
                      'Los equipos no se borran: si uno se retira, se marca '
                      'como inactivo y queda su historial.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
