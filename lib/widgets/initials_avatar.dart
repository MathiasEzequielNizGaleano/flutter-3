import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// "María González" → "MG". Usa las dos primeras palabras.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.substring(0, 1).toUpperCase()).join();
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.initials, {
    super.key,
    this.size = 40,
    this.dimmed = false,
  });

  final String initials;
  final double size;

  /// Para cuentas dadas de baja o vínculos terminados.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Container(
          width: size,
          height: size,
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
              initials,
              style: AppTextStyles.display(
                fontSize: size * 0.33,
                color: AppColors.bgPanel2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
