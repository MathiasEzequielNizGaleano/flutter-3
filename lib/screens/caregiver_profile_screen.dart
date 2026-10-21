import 'package:flutter/material.dart';

import '../navigation/nav_items.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/screen_title.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/info_card.dart';
import '../widgets/profile_parts.dart';
import '../widgets/status_badge.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class CaregiverProfileScreen extends StatelessWidget {
  const CaregiverProfileScreen({super.key});

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
                          colors: [AppColors.violet, AppColors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        'MG',
                        style: AppTextStyles.display(
                          fontSize: 20,
                          color: AppColors.bgPanel2,
                        ),
                      ),
                    ),
                    Text(
                      'María González',
                      style: AppTextStyles.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const StatusBadge(
                      text: 'Cuidadora · Madre',
                      tone: StatusBadgeTone.warn,
                    ),
                  ],
                ),
              ),
              const ProfileSectionTitle('Datos personales'),
              const InfoCard(
                rows: [
                  InfoRow('Documento', value: '3.998.201'),
                  InfoRow('Fecha de nacimiento', value: '22 jul 1970'),
                  InfoRow('Sexo', value: 'Femenino'),
                  InfoRow('Ocupación', value: 'Ama de casa'),
                ],
              ),
              const ProfileSectionTitle('Contacto'),
              const InfoCard(
                rows: [
                  InfoRow('Teléfono', value: '0982 111 222'),
                  InfoRow(
                    'Correo alternativo',
                    value: 'maria.gonzalez@mail.com',
                  ),
                  InfoRow('Dirección', value: 'San Lorenzo, PY'),
                ],
              ),
              const ProfileSectionTitle('Pacientes a cargo'),
              Container(
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
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.violet, AppColors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        'MR',
                        style: AppTextStyles.display(
                          fontSize: 13,
                          color: AppColors.bgPanel2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marcos Rojas',
                            style: AppTextStyles.body(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Principal · puede editar datos y calibrar',
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: AppColors.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const ProfileSectionTitle('Cuenta'),
              const InfoCard(
                rows: [
                  InfoRow('Correo', value: 'maria.gonzalez@mail.com'),
                  InfoRow('Último acceso', value: 'Hoy, 08:10'),
                  InfoRow('Miembro desde', value: 'Feb 2024'),
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
        items: caregiverNavItems(),
        currentIndex: 4,
      ),
    );
  }
}
