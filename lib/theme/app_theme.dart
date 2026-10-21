import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme extends ChangeNotifier {
  AppTheme._() {
    _apply(_systemBrightness());
  }

  static final AppTheme instance = AppTheme._();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  bool get isDark => AppColors.isDark;

  Brightness _systemBrightness() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  void _apply(Brightness brightness) {
    AppColors.palette = brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    syncWithSystem(force: true);
  }

  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  void syncWithSystem({bool force = false}) {
    final target = switch (_mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => _systemBrightness(),
    };
    if (!force && target == AppColors.palette.brightness) return;
    _apply(target);
    notifyListeners();
  }

  ThemeData get themeData {
    final palette = AppColors.palette;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.cyan,
        brightness: palette.brightness,
      ),
      scaffoldBackgroundColor: palette.bgDeep,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
