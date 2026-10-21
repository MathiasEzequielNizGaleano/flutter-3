import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.prefix,
    this.linkText,
    this.onLinkTap,
    this.suffix = '',
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String prefix;
  final String? linkText;
  final VoidCallback? onLinkTap;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body(fontSize: 12, color: AppColors.textMute);

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            side: BorderSide(color: AppColors.line, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            activeColor: AppColors.cyan,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  text: prefix,
                  style: style,
                  children: [
                    if (linkText != null)
                      TextSpan(
                        text: linkText,
                        style: style.copyWith(
                          color: AppColors.cyan,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: onLinkTap == null
                            ? null
                            : (TapGestureRecognizer()..onTap = onLinkTap),
                      ),
                    TextSpan(text: suffix),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
