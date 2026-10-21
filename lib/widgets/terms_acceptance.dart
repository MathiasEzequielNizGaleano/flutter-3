import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:headmouse_pro/theme/app_colors.dart';
import 'package:headmouse_pro/theme/app_text_styles.dart';

class TermsAcceptance extends StatelessWidget {
  const TermsAcceptance({
    super.key,
    required this.value,
    required this.onChanged,
    this.onPolicyTap,
    this.includeTerms = false,
    this.onTermsTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onPolicyTap;

  final bool includeTerms;
  final VoidCallback? onTermsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          side: BorderSide(color: AppColors.line, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          activeColor: AppColors.cyan,
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: includeTerms ? 'Acepto los ' : 'Acepto la ',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textMute,
              ),
              children: [
                if (includeTerms) ...[
                  TextSpan(
                    text: 'Términos y Condiciones',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.cyan,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: onTermsTap == null
                        ? null
                        : (TapGestureRecognizer()..onTap = onTermsTap),
                  ),
                  const TextSpan(text: ' y la '),
                ],
                TextSpan(
                  text: includeTerms
                      ? 'Política de privacidad'
                      : 'política de privacidad',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.cyan,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: onPolicyTap == null
                      ? null
                      : (TapGestureRecognizer()..onTap = onPolicyTap),
                ),
                TextSpan(
                  text: includeTerms
                      ? '.'
                      : ' y el tratamiento de datos clínicos.',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
