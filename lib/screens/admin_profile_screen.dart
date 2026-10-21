import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/info_card.dart';
import '../widgets/profile_parts.dart';
import '../widgets/status_badge.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _showDemoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message (demo, sin backend)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle('Mi perfil'),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  spacing: 8,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.cyan, AppColors.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        'AD',
                        style: AppTextStyles.display(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      'admin_root',
                      style: AppTextStyles.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const StatusBadge(
                      text: 'Administrador',
                      tone: StatusBadgeTone.warn,
                    ),
                  ],
                ),
              ),
              const ProfileSectionTitle('Datos de cuenta'),
              const InfoCard(
                rows: [
                  InfoRow('Nombre', value: 'Adrián Ortiz'),
                  InfoRow('Correo', value: 'admin@headmousepro.com'),
                  InfoRow('Teléfono', value: '0983 555 000'),
                  InfoRow('Miembro desde', value: 'Ene 2024'),
                ],
              ),
              const ProfileSectionTitle('Actividad'),
              const InfoCard(
                rows: [
                  InfoRow('Último acceso', value: 'Hoy, 07:52'),
                  InfoRow('IP de último acceso', value: '190.x.x.10'),
                  InfoRow('Usuarios gestionados', value: '128'),
                ],
              ),
              const ProfileSectionTitle('Seguridad'),
              const InfoCard(
                rows: [
                  InfoRow(
                    'Verificación en 2 pasos',
                    trailing: StatusBadge(text: 'Activa'),
                  ),
                  InfoRow('Rol', value: 'ADMINISTRADOR'),
                ],
              ),
              const SizedBox(height: 16),
              GhostButton(
                'Editar datos personales',
                onPressed: () =>
                    _showDemoMessage(context, 'Editar datos personales'),
              ),
              GhostButton(
                'Cambiar contraseña',
                onPressed: () =>
                    _showDemoMessage(context, 'Cambiar contraseña'),
              ),
              GhostButton(
                'Ir a Diagnósticos',
                onPressed: () =>
                    _push(context, adminNavItems()[2].builder(context)),
              ),
              GhostButton(
                'Política de privacidad',
                onPressed: () => _push(context, const PrivacyPolicyScreen()),
              ),
              GhostButton(
                'Términos y Condiciones',
                onPressed: () => _push(context, const TermsScreen()),
              ),
              const ThemeToggleTile(),
              const LogoutButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: adminNavItems(),
        currentIndex: 4,
      ),
    );
  }
}
