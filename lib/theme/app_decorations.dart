import 'package:flutter/material.dart';

import 'app_colors.dart';

BoxDecoration glassCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.overlay,
    border: Border.all(color: AppColors.line, width: 1),
    borderRadius: BorderRadius.circular(radius),
  );
}
