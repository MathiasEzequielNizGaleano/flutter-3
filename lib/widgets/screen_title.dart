import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: AppTextStyles.display(fontSize: 20)),
    );
  }
}
