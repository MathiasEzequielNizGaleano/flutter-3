import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'accessible_tap.dart';

class RoleOption {
  const RoleOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.label,
    required this.roles,
    required this.selectedRole,
    required this.onChanged,
  });

  final String label;
  final List<RoleOption> roles;
  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: AppColors.overlay,
        border: Border.all(color: AppColors.line, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        spacing: 9,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: AppTextStyles.mono()),
          ),
          for (final role in roles)
            AccessibleTap(
              onTap: () => onChanged(role.label),
              label: role.label,
              selected: selectedRole == role.label,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: selectedRole == role.label
                      ? AppColors.cyan.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: selectedRole == role.label
                        ? AppColors.cyan
                        : AppColors.line,
                    width: 1,
                  ),
                  boxShadow: selectedRole == role.label
                      ? [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.5),
                            blurRadius: 30,
                          ),
                        ]
                      : [],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 12,
                  children: [
                    Row(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          role.icon,
                          size: 20,
                          color: selectedRole == role.label
                              ? AppColors.text
                              : AppColors.textMute,
                        ),
                        Text(
                          role.label,
                          style: AppTextStyles.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedRole == role.label
                                ? AppColors.text
                                : AppColors.textMute,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedRole == role.label
                            ? AppColors.cyan
                            : Colors.transparent,
                        border: Border.all(
                          color: selectedRole == role.label
                              ? AppColors.cyan
                              : AppColors.line,
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
