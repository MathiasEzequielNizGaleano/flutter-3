import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RecaptchaPlaceholder extends StatelessWidget {
  const RecaptchaPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.transparent,
        border: Border.all(color: AppColors.line, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 12,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    border: Border.all(color: AppColors.line, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(width: 32, height: 32),
                ),
                Flexible(
                  child: Text(
                    'No soy un robot',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  gradient: LinearGradient(
                    colors: [AppColors.cyan, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(width: 40, height: 40),
              ),
              const SizedBox(height: 4),
              Text(
                'reCAPTCHA',
                style: AppTextStyles.mono(fontSize: 10, color: AppColors.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
