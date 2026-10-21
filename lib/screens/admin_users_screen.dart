import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class _UserEntry {
  const _UserEntry(
    this.initials,
    this.name,
    this.email,
    this.role,
    this.active,
  );

  final String initials;
  final String name;
  final String email;
  final String role;
  final bool active;
}

const _users = [
  _UserEntry('JP', 'Juan Paredes', 'juan.paredes@correo.com', 'Paciente', true),
  _UserEntry('MR', 'Marcos Rojas', 'marcos.rojas@correo.com', 'Paciente', true),
  _UserEntry(
    'LF',
    'Lucía Fernández',
    'lucia.fernandez@correo.com',
    'Paciente',
    false,
  ),
  _UserEntry(
    'MG',
    'María González',
    'maria.gonzalez@correo.com',
    'Cuidador',
    true,
  ),
  _UserEntry(
    'CH',
    'Carlos Herrera',
    'carlos.herrera@correo.com',
    'Cuidador',
    true,
  ),
  _UserEntry('AR', 'admin_root', 'admin@headmouse.app', 'Admin', true),
];

const _roleFilters = ['Todos', 'Pacientes', 'Cuidadores', 'Admins'];

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _filter = 'Todos';
  String _query = '';

  bool _matchesRole(_UserEntry user) => switch (_filter) {
    'Pacientes' => user.role == 'Paciente',
    'Cuidadores' => user.role == 'Cuidador',
    'Admins' => user.role == 'Admin',
    _ => true,
  };

  StatusBadgeTone _toneFor(String role) => switch (role) {
    'Paciente' => StatusBadgeTone.ok,
    'Cuidador' => StatusBadgeTone.violet,
    _ => StatusBadgeTone.warn,
  };

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = _users.where(
      (user) =>
          _matchesRole(user) &&
          (query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query)),
    );

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: AsyncBody(
          loader: simulateFetch,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenTitle('Usuarios'),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: AppTextStyles.body(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo',
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
                  options: _roleFilters,
                  selected: _filter,
                  onChanged: (chip) => setState(() => _filter = chip),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const EmptyState(
                    title: 'No hay usuarios',
                    message:
                        'Prueba con otra búsqueda o cambia el filtro de rol.',
                    icon: Icons.group_outlined,
                  ),
                for (final user in visible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: glassCardDecoration(radius: 14),
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
                              user.initials,
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
                            spacing: 2,
                            children: [
                              Text(
                                user.name,
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
                              text: user.role,
                              tone: _toneFor(user.role),
                            ),
                            Text(
                              user.active ? 'Activo' : 'Inactivo',
                              style: AppTextStyles.mono(
                                fontSize: 10,
                                color: user.active
                                    ? AppColors.cyan
                                    : AppColors.textMute,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 1,
      ),
    );
  }
}
