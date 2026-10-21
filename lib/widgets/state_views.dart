import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';

Future<void> simulateFetch() =>
    Future<void>.delayed(const Duration(milliseconds: 700));

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = AppStrings.loading});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.cyan,
              ),
            ),
            Text(
              message,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: glassCardDecoration(radius: 14),
      child: Column(
        spacing: 8,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 30, color: AppColors.textMute),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 11.5,
                color: AppColors.textMute,
              ),
            ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.onRetry,
    this.message = AppStrings.errorMessage,
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 36,
                color: AppColors.textMute,
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Column(
                spacing: 12,
                children: [
                  Text(
                    AppStrings.errorTitle,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMute,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, size: 18, color: AppColors.cyan),
              label: Text(
                AppStrings.retry,
                style: AppTextStyles.body(color: AppColors.cyan),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.cyan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncBody extends StatefulWidget {
  const AsyncBody({super.key, required this.loader, required this.builder});

  final Future<void> Function() loader;
  final WidgetBuilder builder;

  @override
  State<AsyncBody> createState() => _AsyncBodyState();
}

class _AsyncBodyState extends State<AsyncBody> {
  late Future<void> _future = widget.loader();

  void _retry() {
    setState(() {
      _future = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError) return ErrorView(onRetry: _retry);
        return widget.builder(context);
      },
    );
  }
}
