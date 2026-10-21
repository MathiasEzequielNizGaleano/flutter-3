import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import 'login_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.navItems,
    required this.currentIndex,
    this.showLogout = false,
  });

  final String title;
  final List<AppNavItem> navItems;
  final int currentIndex;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.text,
        title: Text(title, style: AppTextStyles.display(fontSize: 18)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Próximamente',
              style: AppTextStyles.body(color: AppColors.textMute),
            ),
            if (showLogout) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                icon: Icon(Icons.logout, color: AppColors.coral, size: 18),
                label: Text(
                  'Cerrar sesión',
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.coral.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: navItems,
        currentIndex: currentIndex,
      ),
    );
  }
}
