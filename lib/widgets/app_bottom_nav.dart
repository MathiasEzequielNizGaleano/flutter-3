import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  final List<AppNavItem> items;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPanel,
      selectedItemColor: AppColors.cyan,
      unselectedItemColor: AppColors.textMute,
      selectedLabelStyle: AppTextStyles.body(
        fontSize: 11,
        color: AppColors.cyan,
      ),
      unselectedLabelStyle: AppTextStyles.body(
        fontSize: 11,
        color: AppColors.textMute,
      ),
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: items[index].builder),
        );
      },
      items: [
        for (final item in items)
          BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}
