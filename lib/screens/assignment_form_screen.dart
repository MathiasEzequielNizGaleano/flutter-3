import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/care_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_input_decoration.dart';
import '../theme/app_text_styles.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/filter_chips.dart';
import '../widgets/gradient_button.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/state_views.dart';

/// Crear, editar, terminar o reactivar un vínculo cuidador ↔ paciente.
/// [fixed] es el usuario desde el que se abrió (paciente o cuidador); la
/// otra parte se elige de la lista. Al terminar vuelve con un mensaje.
class AssignmentFormScreen extends StatefulWidget {
  const AssignmentFormScreen({
    super.key,
    required this.fixed,
    this.existing,
    this.excludeUids = const {},
  });

  final ManagedUser fixed;
  final CareAssignment? existing;

  /// Usuarios que no se ofrecen porque ya tienen un vínculo vigente.
  final Set<String> excludeUids;

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final bool _isPatient = widget.fixed.role == UserRole.paciente;
  late final Stream<List<ManagedUser>> _users = AdminService.instance
      .watchUsers();
  List<ManagedUser> _latestUsers = const [];

  String? _otherUid;
  late String? _parentesco = widget.existing?.parentesco;
  late Responsibility _resp =
      widget.existing?.responsabilidad ?? Responsibility.principal;
  late CarePermissions _perms =
      widget.existing?.permisos ?? const CarePermissions();
  bool _saving = false;

  CareAssignment? get _existing => widget.existing;
  bool get _isActive => _existing?.activo ?? false;
  UserRole get _otherRole => _isPatient ? UserRole.cuidador : UserRole.paciente;
  String get _otherLabel => _isPatient ? 'cuidador' : 'paciente';

  List<String> get _kinships => [
    ...kinshipOptions,
    // Un parentesco cargado antes que ya no está en la lista.
    if (_parentesco != null && !kinshipOptions.contains(_parentesco))
      _parentesco!,
  ];

  /// La otra parte del vínculo, desde la lista de usuarios o, si no está
  /// (por ejemplo, la reactivación de alguien dado de baja), desde los
  /// nombres guardados en el vínculo.
  ManagedUser _other() {
    final uid =
        _otherUid ??
        (_isPatient ? _existing!.idCuidador : _existing!.idPaciente);
    for (final user in _latestUsers) {
      if (user.uid == uid) return user;
    }
    return ManagedUser(
      uid: uid,
      email: '',
      role: _otherRole,
      nombres: _isPatient
          ? _existing!.nombreCuidador
          : _existing!.nombrePaciente,
    );
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
    final existing = _existing;
    if (existing != null && existing.activo) {
      await _run(
        () => CareService.instance.update(
          existing,
          parentesco: _parentesco!,
          responsabilidad: _resp,
          permisos: _perms,
        ),
        'Vínculo actualizado.',
      );
      return;
    }
    final other = _other();
    final caregiver = _isPatient ? other : widget.fixed;
    final patient = _isPatient ? widget.fixed : other;
    await _run(
      () => CareService.instance.assign(
        caregiver: caregiver,
        patient: patient,
        parentesco: _parentesco!,
        responsabilidad: _resp,
        permisos: _perms,
      ),
      '${caregiver.fullName} ahora cuida a ${patient.fullName}.',
    );
  }

  Future<void> _end() async {
    final existing = _existing!;
    final confirmed = await confirmAction(
      context,
      title: '¿Terminar el vínculo?',
      message:
          '${existing.nombreCuidador} deja de ver y de configurar a '
          '${existing.nombrePaciente}. El vínculo queda en el historial y se '
          'puede reactivar.',
      confirmLabel: 'Sí, terminar',
    );
    if (!confirmed) return;
    await _run(() => CareService.instance.end(existing), 'Vínculo terminado.');
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(
          existing == null
              ? 'Asignar $_otherLabel'
              : (_isActive ? 'Editar vínculo' : 'Vínculo terminado'),
          style: AppTextStyles.display(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ManagedUser>>(
          stream: _users,
          builder: (context, snapshot) {
            if (snapshot.hasData) _latestUsers = snapshot.data!;
            if (existing == null && !snapshot.hasData) {
              return snapshot.hasError
                  ? ErrorView(
                      onRetry: () => Navigator.pop(context),
                      message: AuthService.describeError(snapshot.error!),
                    )
                  : const LoadingView();
            }
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final existing = _existing;
    final candidates = _latestUsers
        .where(
          (u) =>
              u.role == _otherRole &&
              u.active &&
              !widget.excludeUids.contains(u.uid),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PersonRow(
              label: _isPatient ? 'Paciente' : 'Cuidador',
              name: widget.fixed.fullName,
            ),
            const SizedBox(height: 10),
            if (existing != null)
              _PersonRow(
                label: _isPatient ? 'Cuidador' : 'Paciente',
                name: _isPatient
                    ? existing.nombreCuidador
                    : existing.nombrePaciente,
              )
            else if (candidates.isEmpty)
              EmptyState(
                title: 'No hay ${_otherLabel}s disponibles',
                message:
                    'Primero dalo de alta desde Usuarios con el rol '
                    '${_otherRole.label}.',
                icon: Icons.person_search_outlined,
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _otherUid,
                isExpanded: true,
                dropdownColor: AppColors.bgPanel,
                decoration: appFieldDecoration(
                  hintText: 'Elegí el $_otherLabel',
                  icon: Icons.person_outline,
                ),
                style: AppTextStyles.body(fontSize: 13),
                items: [
                  for (final user in candidates)
                    DropdownMenuItem(
                      value: user.uid,
                      child: Text(
                        '${user.fullName} · ${user.email}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (uid) =>
                    uid == null ? 'Elegí un $_otherLabel.' : null,
                onChanged: (uid) => setState(() => _otherUid = uid),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _parentesco,
              isExpanded: true,
              dropdownColor: AppColors.bgPanel,
              decoration: appFieldDecoration(
                hintText: 'Parentesco o relación con el paciente',
                icon: Icons.family_restroom,
              ),
              style: AppTextStyles.body(fontSize: 13),
              items: [
                for (final kinship in _kinships)
                  DropdownMenuItem(value: kinship, child: Text(kinship)),
              ],
              validator: (value) =>
                  value == null ? 'Elegí el parentesco.' : null,
              onChanged: (value) => setState(() => _parentesco = value),
            ),
            const SizedBox(height: 16),
            _SectionLabel('TIPO DE RESPONSABILIDAD'),
            FilterChips(
              options: [for (final r in Responsibility.values) r.label],
              selected: _resp.label,
              onChanged: (label) => setState(
                () => _resp = Responsibility.values.firstWhere(
                  (r) => r.label == label,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel('PERMISOS SOBRE EL PACIENTE'),
            Container(
              decoration: glassCardDecoration(radius: 14),
              // Material propio para que se vea el efecto al tocar.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    // Editar implica ver: sin ver la ficha no se puede
                    // cargar nada en ella.
                    _PermissionSwitch(
                      'Ver sus datos',
                      _perms.verDatos,
                      (v) => setState(
                        () => _perms = _perms.copyWith(
                          verDatos: v,
                          editarDatos: v ? null : false,
                        ),
                      ),
                    ),
                    _PermissionSwitch(
                      'Editar sus datos y diagnósticos',
                      _perms.editarDatos,
                      (v) => setState(
                        () => _perms = _perms.copyWith(
                          editarDatos: v,
                          verDatos: v ? true : null,
                        ),
                      ),
                    ),
                    _PermissionSwitch(
                      'Configurar el HeadMouse',
                      _perms.configurar,
                      (v) => setState(
                        () => _perms = _perms.copyWith(configurar: v),
                      ),
                    ),
                    _PermissionSwitch(
                      'Calibrar el HeadMouse',
                      _perms.calibrar,
                      (v) =>
                          setState(() => _perms = _perms.copyWith(calibrar: v)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (existing != null || candidates.isNotEmpty)
              GradientButton(
                label: _saving
                    ? 'Guardando…'
                    : existing == null
                    ? 'Asignar'
                    : (_isActive ? 'Guardar cambios' : 'Reactivar vínculo'),
                onPressed: _saving ? null : _save,
              ),
            if (_isActive) ...[
              const SizedBox(height: 10),
              OutlineActionButton(
                label: 'Terminar vínculo',
                onPressed: _saving ? null : _end,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
    ),
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: glassCardDecoration(radius: 14),
      child: Row(
        spacing: 12,
        children: [
          InitialsAvatar(initialsOf(name), size: 34),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    color: AppColors.textMute,
                  ),
                ),
                Text(
                  name,
                  style: AppTextStyles.body(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionSwitch extends StatelessWidget {
  const _PermissionSwitch(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.cyan,
      title: Text(label, style: AppTextStyles.body(fontSize: 13)),
    );
  }
}
