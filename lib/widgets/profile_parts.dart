import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

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
      onPressed: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      ),
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
