import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/info_card.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/profile_parts.dart';
import '../widgets/screen_title.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';
import 'admin_assignments_screen.dart';
import 'admin_user_form_screen.dart';
import 'caregiver_record_screen.dart';
import 'patient_record_screen.dart';

const _filters = ['Todos', 'Pacientes', 'Cuidadores', 'Admins', 'Inactivos'];

String? _currentUid() => AuthService.instance.currentUid;

StatusBadgeTone roleTone(UserRole? role) => switch (role) {
  UserRole.paciente => StatusBadgeTone.ok,
  UserRole.cuidador => StatusBadgeTone.violet,
  UserRole.admin => StatusBadgeTone.warn,
  null => StatusBadgeTone.mute,
};

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.initialFilter = 'Todos'});

  final String initialFilter;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late String _filter = widget.initialFilter;
  String _query = '';
  late Stream<List<ManagedUser>> _users = AdminService.instance.watchUsers();

  bool _matchesFilter(ManagedUser user) => switch (_filter) {
    'Pacientes' => user.role == UserRole.paciente,
    'Cuidadores' => user.role == UserRole.cuidador,
    'Admins' => user.role == UserRole.admin,
    'Inactivos' => !user.active,
    _ => true,
  };

  void _retry() {
    setState(() => _users = AdminService.instance.watchUsers());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreate() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AdminUserFormScreen()),
    );
    if (message != null && mounted) _showMessage(message);
  }

  Future<void> _openUser(ManagedUser user) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserSheet(user: user, isSelf: user.uid == _currentUid()),
    );
    if (message != null && mounted) _showMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: StreamBuilder<List<ManagedUser>>(
          stream: _users,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                onRetry: _retry,
                message: AuthService.describeError(snapshot.error!),
              );
            }
            if (!snapshot.hasData) return const LoadingView();
            return _buildList(snapshot.data!);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.bgPanel2,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          'Dar de alta',
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.bgPanel2,
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 1,
      ),
    );
  }

  Widget _buildList(List<ManagedUser> users) {
    final query = _query.trim().toLowerCase();
    final visible = users
        .where(
          (user) =>
              _matchesFilter(user) &&
              (query.isEmpty ||
                  user.fullName.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query) ||
                  user.documento.toLowerCase().contains(query)),
        )
        .toList();
    final selfUid = _currentUid();

    return SingleChildScrollView(
      // Espacio abajo para que el botón flotante no tape la última tarjeta.
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle('Usuarios'),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            style: AppTextStyles.body(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, correo o documento',
              hintStyle: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMute,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: AppColors.textMute,
              ),
              filled: true,
              fillColor: AppColors.overlay,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilterChips(
            options: _filters,
            selected: _filter,
            onChanged: (chip) => setState(() => _filter = chip),
          ),
          const SizedBox(height: 10),
          Text(
            visible.length == 1 ? '1 usuario' : '${visible.length} usuarios',
            style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMute),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            EmptyState(
              title: 'No hay usuarios',
              message: users.isEmpty
                  ? 'Todavía no hay cuentas. Usá "Dar de alta" para crear '
                        'la primera.'
                  : 'Probá con otra búsqueda o cambiá el filtro.',
              icon: Icons.group_outlined,
            ),
          for (final user in visible)
            _UserTile(
              user: user,
              isSelf: user.uid == selfUid,
              onTap: () => _openUser(user),
            ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isSelf,
    required this.onTap,
  });

  final ManagedUser user;
  final bool isSelf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: glassCardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              spacing: 12,
              children: [
                InitialsAvatar(user.initials, dimmed: !user.active),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        isSelf ? '${user.fullName} (vos)' : user.fullName,
                        style: AppTextStyles.body(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.email,
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: AppColors.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 6,
                  children: [
                    StatusBadge(
                      text: user.roleLabel,
                      tone: roleTone(user.role),
                    ),
                    Text(
                      user.active ? 'Activo' : 'De baja',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: user.active ? AppColors.cyan : AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detalle de una cuenta con las acciones del administrador. Al cerrarse
/// devuelve el mensaje a mostrar, o `null` si no se hizo nada.
class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.user, required this.isSelf});

  final ManagedUser user;
  final bool isSelf;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  bool _busy = false;

  ManagedUser get _user => widget.user;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context, done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.describeError(e))));
    }
  }

  Future<void> _edit() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: _user)),
    );
    if (message != null && mounted) Navigator.pop(context, message);
  }

  Future<void> _changeRole() async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (context) => _RoleDialog(current: _user.role),
    );
    if (role == null || role == _user.role) return;
    await _run(
      () => AdminService.instance.setRole(_user, role),
      '${_user.fullName} ahora es ${role.label}.',
    );
  }

  Future<void> _toggleActive() async {
    final deactivate = _user.active;
    final confirmed = await confirmAction(
      context,
      title: deactivate
          ? '¿Dar de baja a ${_user.fullName}?'
          : '¿Reactivar a ${_user.fullName}?',
      message: deactivate
          ? 'No va a poder iniciar sesión hasta que la reactives. Sus datos '
                'y su historial no se borran.'
          : 'Va a poder volver a iniciar sesión con su correo y '
                'contraseña de siempre.',
      confirmLabel: deactivate ? 'Sí, dar de baja' : 'Sí, reactivar',
      danger: deactivate,
    );
    if (!confirmed) return;
    await _run(
      () => AdminService.instance.setActive(_user, !deactivate),
      deactivate
          ? '${_user.fullName} quedó dado de baja.'
          : '${_user.fullName} fue reactivado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 12,
              children: [
                InitialsAvatar(user.initials, size: 52, dimmed: !user.active),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        user.fullName,
                        style: AppTextStyles.display(fontSize: 16),
                      ),
                      Text(
                        user.email,
                        style: AppTextStyles.body(
                          fontSize: 11.5,
                          color: AppColors.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoCard(
              rows: [
                InfoRow(
                  'Rol',
                  trailing: StatusBadge(
                    text: user.roleLabel,
                    tone: roleTone(user.role),
                  ),
                ),
                InfoRow(
                  'Estado',
                  trailing: StatusBadge(
                    text: user.active ? 'Activo' : 'De baja',
                    tone: user.active
                        ? StatusBadgeTone.ok
                        : StatusBadgeTone.mute,
                  ),
                ),
                InfoRow(
                  'Documento',
                  value: user.documento.isEmpty ? '—' : user.documento,
                ),
                InfoRow(
                  'Alta',
                  value: user.fechaRegistro == null
                      ? '—'
                      : formatShortDate(user.fechaRegistro!),
                ),
                InfoRow(
                  'Último ingreso',
                  value: user.ultimoIngreso == null
                      ? 'Nunca'
                      : formatEventTime(user.ultimoIngreso!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingView(message: 'Guardando…'),
              )
            else ...[
              if (user.role == UserRole.paciente)
                GhostButton(
                  'Ficha del paciente',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientRecordScreen(
                        patientUid: user.uid,
                        patientName: user.fullName,
                        canEdit: true,
                      ),
                    ),
                  ),
                ),
              if (user.role == UserRole.cuidador)
                GhostButton(
                  'Ficha del cuidador',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CaregiverRecordScreen(user: user),
                    ),
                  ),
                ),
              if (user.role == UserRole.paciente ||
                  user.role == UserRole.cuidador)
                GhostButton(
                  user.role == UserRole.paciente
                      ? 'Cuidadores asignados'
                      : 'Pacientes asignados',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminAssignmentsScreen(user: user),
                    ),
                  ),
                ),
              GhostButton('Editar datos', onPressed: _edit),
              if (widget.isSelf)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(
                    'Es tu cuenta: tu rol y tu estado solo los puede cambiar '
                    'otro administrador.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 11.5,
                      color: AppColors.textMute,
                    ),
                  ),
                )
              else ...[
                GhostButton('Cambiar rol', onPressed: _changeRole),
                OutlineActionButton(
                  label: user.active ? 'Dar de baja' : 'Reactivar cuenta',
                  danger: user.active,
                  onPressed: _toggleActive,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleDialog extends StatelessWidget {
  const _RoleDialog({required this.current});

  final UserRole? current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgPanel,
      shape: appDialogShape(),
      title: Text(
        'Cambiar rol',
        style: AppTextStyles.display(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: RadioGroup<UserRole>(
        groupValue: current,
        onChanged: (role) => Navigator.pop(context, role),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in UserRole.values)
              RadioListTile<UserRole>(
                value: role,
                activeColor: AppColors.cyan,
                title: Text(
                  role.label,
                  style: AppTextStyles.body(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        GhostButton('Cancelar', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
