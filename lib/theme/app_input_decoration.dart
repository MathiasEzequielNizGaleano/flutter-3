import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

InputDecoration appFieldDecoration({
  String? hintText,
  IconData? icon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  return InputDecoration(
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: AppColors.cyan, size: 18),
    suffixIcon: suffixIcon,
    hintText: hintText,
    hintStyle: AppTextStyles.body(fontSize: 13, color: AppColors.textMute),
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.cyan),
    errorBorder: border(AppColors.coral),
    focusedErrorBorder: border(AppColors.coral),
    errorMaxLines: 3,
    errorStyle: AppTextStyles.body(fontSize: 11.5, color: AppColors.coral),
  );
}
