import 'package:flutter/material.dart';

import '../navigation/session_guard.dart';
import '../screens/login_screen.dart';
import '../screens/two_factor_settings_screen.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'confirm_dialog.dart';
import 'info_card.dart';
import 'status_badge.dart';

/// Envía el correo para cambiar la contraseña de la sesión actual.
class ChangePasswordButton extends StatelessWidget {
  const ChangePasswordButton({super.key});

  Future<void> _send(BuildContext context) async {
    final email = AuthService.instance.current?.email;
    if (email == null || email.isEmpty) return;
    final confirmed = await confirmAction(
      context,
      title: 'Cambiar contraseña',
      message:
          'Te vamos a enviar un correo a $email con un enlace para elegir una '
          'contraseña nueva.',
      confirmLabel: 'Enviar correo',
      danger: false,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.sendPasswordReset(email);
      messenger.showSnackBar(
        SnackBar(content: Text('Listo. Revisá tu correo ($email).')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.describeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      GhostButton('Cambiar contraseña', onPressed: () => _send(context));
}

/// Seguridad de la cuenta: dónde llega el código de la verificación en dos
/// pasos (con el botón para cambiarlo) y cierre de las otras sesiones.
class SecuritySection extends StatefulWidget {
  const SecuritySection({super.key, this.extraRows = const []});

  final List<InfoRow> extraRows;

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> {
  Future<void> _open(AppUser user) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => TwoFactorSettingsScreen(user: user)),
    );
    if (message == null || !mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _closeOthers(AppUser user) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Cerrar las otras sesiones?',
      message:
          'Se cierra tu sesión en cualquier otro teléfono donde hayas '
          'ingresado. En este seguís conectado.',
      confirmLabel: 'Cerrar las otras',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SessionService.instance.closeOthers(user);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Listo. Se cerró tu sesión en los demás dispositivos.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.describeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle('Seguridad'),
        InfoCard(
          rows: [
            const InfoRow(
              'Verificación en 2 pasos',
              trailing: StatusBadge(text: 'Activa'),
            ),
            InfoRow(
              'Código por',
              value: user == null ? 'Correo' : twoFactorSummary(user),
            ),
            ...widget.extraRows,
          ],
        ),
        if (user != null) ...[
          const SizedBox(height: 10),
          GhostButton(
            'Cambiar dónde recibo el código',
            onPressed: () => _open(user),
          ),
          GhostButton(
            'Cerrar sesión en los otros dispositivos',
            onPressed: () => _closeOthers(user),
          ),
        ],
      ],
    );
  }
}

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.mono(fontSize: 11, letterSpacing: 0.8),
    ),
  );
}

class GhostButton extends StatelessWidget {
  const GhostButton(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    ),
  );
}

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppTheme.instance,
      builder: (context, _) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: glassCardDecoration(radius: 12),
        // Material propio: el ListTile pinta fondo y salpicadura en el
        // Material más cercano y quedarían ocultos bajo la decoración.
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            value: AppTheme.instance.isDark,
            onChanged: (_) => AppTheme.instance.toggle(),
            activeThumbColor: AppColors.cyan,
            secondary: Icon(
              AppTheme.instance.isDark ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.cyan,
            ),
            title: Text(
              AppStrings.darkMode,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              AppStrings.darkModeSubtitle,
              style: AppTextStyles.body(
                fontSize: 11.5,
                color: AppColors.textMute,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () async {
        final navigator = Navigator.of(context);
        SessionGuard.stop();
        await AuthService.instance.signOut();
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      },
      icon: Icon(Icons.logout, color: AppColors.coral, size: 18),
      label: Text(
        'Cerrar sesión',
        style: AppTextStyles.body(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.coral,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: AppColors.coral.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
