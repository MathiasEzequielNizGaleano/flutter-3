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

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

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
                        'MR',
                        style: AppTextStyles.display(
                          fontSize: 20,
                          color: AppColors.bgPanel2,
                        ),
                      ),
                    ),
                    Text(
                      'Marcos Rojas',
                      style: AppTextStyles.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const StatusBadge(text: 'Paciente'),
                  ],
                ),
              ),
              const ProfileSectionTitle('Datos personales'),
              const InfoCard(
                rows: [
                  InfoRow('Documento', value: '4.512.897'),
                  InfoRow('Fecha de nacimiento', value: '14 mar 1998'),
                  InfoRow('Sexo', value: 'Masculino'),
                  InfoRow('Teléfono', value: '0981 234 567'),
                  InfoRow('Dirección', value: 'San Lorenzo, PY'),
                ],
              ),
              const ProfileSectionTitle('Registro SENADIS'),
              const InfoCard(
                rows: [
                  InfoRow('N° de registro', value: 'SEN-2024-00871'),
                  InfoRow('Estado', trailing: StatusBadge(text: 'Activo')),
                ],
              ),
              const ProfileSectionTitle('Contacto de emergencia'),
              const InfoCard(
                rows: [
                  InfoRow('Nombre', value: 'María González'),
                  InfoRow('Teléfono', value: '0982 111 222'),
                ],
              ),
              const ProfileSectionTitle('Datos clínicos funcionales'),
              const InfoCard(
                rows: [
                  InfoRow('Movilidad cervical', value: 'Parcial'),
                  InfoRow('Movilidad miofacial', value: 'Conservada'),
                  InfoRow('Control cefálico', value: 'Estable'),
                  InfoRow('Movimientos involuntarios', value: 'No'),
                  InfoRow(
                    'Observaciones',
                    value:
                        'Mejor control del cursor en sesiones matutinas; '
                        'fatiga cervical notoria después de 40 min de uso '
                        'continuo.',
                    stacked: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Estos datos solo puede modificarlos tu cuidador o el '
                'fisioterapeuta a cargo.',
                style: AppTextStyles.body(
                  fontSize: 10.5,
                  color: AppColors.textMute,
                ),
              ),
              const ProfileSectionTitle('Cuenta'),
              const InfoCard(
                rows: [
                  InfoRow('Correo', value: 'marcos.rojas@mail.com'),
                  InfoRow('Último acceso', value: 'Hoy, 08:15'),
                  InfoRow('Miembro desde', value: 'Mar 2024'),
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
        items: patientHomeNavItems(),
        currentIndex: 4,
      ),
    );
  }
}
