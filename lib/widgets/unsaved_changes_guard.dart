import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
    this.listenable,
  });

  final bool Function() hasChanges;
  final Listenable? listenable;
  final Widget child;

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: Text(
          AppStrings.unsavedTitle,
          style: AppTextStyles.display(fontSize: 16),
        ),
        content: Text(
          AppStrings.unsavedMessage,
          style: AppTextStyles.body(fontSize: 13, color: AppColors.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.keepEditing,
              style: AppTextStyles.body(color: AppColors.cyan),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.discardChanges,
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable ?? Listenable.merge(const []),
      builder: (context, _) => PopScope(
        canPop: !hasChanges(),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _confirmExit(context);
        },
        child: child,
      ),
    );
  }
}
